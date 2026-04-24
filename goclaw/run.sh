#!/usr/bin/env bash
set -e

CONFIG_PATH=/data/options.json

# ── Read addon options ──
POSTGRES_HOST=$(jq -r '.postgres_host' "$CONFIG_PATH")
POSTGRES_PORT=$(jq -r '.postgres_port' "$CONFIG_PATH")
POSTGRES_USER=$(jq -r '.postgres_user' "$CONFIG_PATH")
POSTGRES_PASSWORD=$(jq -r '.postgres_password' "$CONFIG_PATH")
POSTGRES_DATABASE=$(jq -r '.postgres_database' "$CONFIG_PATH")
REDIS_HOST=$(jq -r '.redis_host // empty' "$CONFIG_PATH")
REDIS_PORT=$(jq -r '.redis_port' "$CONFIG_PATH")
ENABLE_BROWSER=$(jq -r '.enable_browser' "$CONFIG_PATH")
GATEWAY_TOKEN=$(jq -r '.gateway_token // empty' "$CONFIG_PATH")
ENCRYPTION_KEY=$(jq -r '.encryption_key // empty' "$CONFIG_PATH")
TRACE_VERBOSE=$(jq -r '.trace_verbose // false' "$CONFIG_PATH")

# ── Data directories ──
mkdir -p /data/goclaw/skills /data/goclaw/workspace

# ── Runtime paths (from docker-entrypoint.sh) ──
# Install targets are ephemeral (wiped every restart/upgrade — always clean
# against the current base image's Python/Node ABI). Package caches live on
# the persistent /data volume so the boot-time reinstall is fast.
RUNTIME_DIR="/app/data/.runtime"
CACHE_DIR="/data/goclaw/.cache"
mkdir -p "$RUNTIME_DIR/pip" "$RUNTIME_DIR/npm-global/lib" 2>/dev/null || true
mkdir -p "$CACHE_DIR/pip" "$CACHE_DIR/npm" 2>/dev/null || true
export PYTHONPATH="$RUNTIME_DIR/pip:${PYTHONPATH:-}"
export PIP_TARGET="$RUNTIME_DIR/pip"
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_CACHE_DIR="$CACHE_DIR/pip"
export NPM_CONFIG_PREFIX="$RUNTIME_DIR/npm-global"
export NPM_CONFIG_CACHE="$CACHE_DIR/npm"
export NODE_PATH="/usr/local/lib/node_modules:$RUNTIME_DIR/npm-global/lib/node_modules:${NODE_PATH:-}"
export PATH="$RUNTIME_DIR/npm-global/bin:$RUNTIME_DIR/pip/bin:$PATH"

# ── Core environment ──
export GOCLAW_POSTGRES_DSN="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DATABASE}?sslmode=disable"
export GOCLAW_CONFIG=/data/goclaw/config.json
export GOCLAW_WORKSPACE=/data/goclaw/workspace
export GOCLAW_DATA_DIR=/data/goclaw
export GOCLAW_SKILLS_DIR=/data/goclaw/skills
export GOCLAW_HOST=0.0.0.0
export GOCLAW_PORT=18790

# ── Gateway token (auto-generate & persist if unset) ──
TOKEN_FILE=/data/goclaw/gateway.token
if [ -z "$GATEWAY_TOKEN" ]; then
    if [ ! -f "$TOKEN_FILE" ]; then
        head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "Generated new gateway token at $TOKEN_FILE"
    fi
    GATEWAY_TOKEN=$(cat "$TOKEN_FILE")
    echo "────────────────────────────────────────────────────────────"
    echo "  Gateway Token (use this to log in to the web dashboard):"
    echo "  $GATEWAY_TOKEN"
    echo "────────────────────────────────────────────────────────────"
fi
export GOCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"

[ -n "$ENCRYPTION_KEY" ] && export GOCLAW_ENCRYPTION_KEY="$ENCRYPTION_KEY"
[ "$TRACE_VERBOSE" = "true" ] && export GOCLAW_TRACE_VERBOSE=1

# ── Redis (external addon only) ──
if [ -n "$REDIS_HOST" ]; then
    export GOCLAW_REDIS_DSN="redis://${REDIS_HOST}:${REDIS_PORT}/0"
    echo "Using Redis at ${REDIS_HOST}:${REDIS_PORT}"
fi

# ── Browser (headless Chromium) ──
# In HA add-on containers there is no system D-Bus and no Google GCM access,
# so Chromium spams ERROR logs at startup for unrelated subsystems
# (UPower, kwallet, accessibility, push notifications). We both (a) disable
# the background services that try to use them and (b) filter the remaining
# noise out of stderr so the add-on log stays readable.
CHROME_PID=""
if [ "$ENABLE_BROWSER" = "true" ]; then
    CHROME_BIN=$(command -v chromium-browser 2>/dev/null || command -v chromium 2>/dev/null || true)
    if [ -n "$CHROME_BIN" ]; then
        echo "Starting headless Chromium..."
        CHROME_LOG_FILTER='dbus/(bus|object_proxy)\.cc|gcm/engine/registration_request\.cc|Failed to connect to the bus|DEPRECATED_ENDPOINT'
        "$CHROME_BIN" \
            --headless=new \
            --no-sandbox \
            --remote-debugging-address=0.0.0.0 \
            --remote-debugging-port=9222 \
            --remote-allow-origins=* \
            --disable-gpu \
            --disable-dev-shm-usage \
            --disable-software-rasterizer \
            --disable-extensions \
            --disable-background-networking \
            --disable-component-update \
            --disable-default-apps \
            --disable-sync \
            --disable-translate \
            --disable-features=MediaSessionService,GlobalMediaControls,OptimizationHints,Translate \
            --no-first-run \
            --no-default-browser-check \
            --no-pings \
            --metrics-recording-only \
            --log-level=2 \
            2> >(grep --line-buffered -vE "$CHROME_LOG_FILTER" >&2) &
        CHROME_PID=$!
        export GOCLAW_BROWSER_REMOTE_URL="ws://localhost:9222"

        for _ in $(seq 1 15); do
            if wget -qO- http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
                echo "Chromium ready (CDP on :9222)"
                break
            fi
            sleep 1
        done
    else
        echo "WARNING: Chromium not found, browser automation disabled"
    fi
fi

# ── Cleanup handler ──
cleanup() {
    echo "Shutting down..."
    [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null || true
    wait 2>/dev/null || true
}
trap cleanup SIGTERM SIGINT

# ── Reinstall skill dependencies ──
# Install targets ($RUNTIME_DIR) are ephemeral, so each boot we re-install
# deps declared by each skill. Caches live on /data so this is fast after
# the first boot. Skills opt in by shipping a requirements.txt (Python) or
# package.json (Node) at the top of their skill directory.
reinstall_skill_deps() {
    [ -d "$GOCLAW_SKILLS_DIR" ] || return 0
    local any=0

    for skill in "$GOCLAW_SKILLS_DIR"/*/; do
        [ -d "$skill" ] || continue
        local name
        name=$(basename "$skill")

        if [ -f "${skill}requirements.txt" ]; then
            echo "  [pip] ${name}"
            pip install --quiet --disable-pip-version-check \
                -r "${skill}requirements.txt" \
                || echo "  WARNING: pip install failed for ${name}"
            any=1
        fi

        if [ -f "${skill}package.json" ]; then
            echo "  [npm] ${name}"
            (cd "$skill" && npm install --silent --no-audit --no-fund --no-progress) \
                || echo "  WARNING: npm install failed for ${name}"
            any=1
        fi
    done

    [ "$any" = "0" ] && echo "  (no skill deps to install)"
}

echo "Reinstalling skill dependencies..."
reinstall_skill_deps

# ── Database upgrade ──
# Applies schema migrations + data hooks. Equivalent to running the
# upstream docker-compose.upgrade.yml overlay. Safe to run on every
# start: it's a no-op when the DB is already up-to-date.
# A real failure here means the DB is in an inconsistent state, so we
# refuse to start the gateway instead of silently serving on a broken
# schema.
echo "Running database upgrade..."
if ! /app/goclaw upgrade; then
    echo "ERROR: database upgrade failed — see output above."
    echo "  The gateway will not start. Check Postgres connectivity,"
    echo "  credentials, and migration logs, or roll back the add-on"
    echo "  to the previous version."
    exit 1
fi

# ── Start GoClaw ──
echo "Starting GoClaw Gateway on :18790..."
/app/goclaw &
GOCLAW_PID=$!
wait "$GOCLAW_PID"
