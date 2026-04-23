# GoClaw Add-ons for Home Assistant

Home Assistant add-on repository for the **GoClaw Gateway** — a PostgreSQL
multi-tenant AI agent gateway with WebSocket RPC, HTTP API, browser
automation, and a web dashboard.

[![Open your Home Assistant instance and show the add-on store with this repository pre-filled.](https://my.home-assistant.io/badges/supervisor_store.svg)](https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2Fimcvampire%2Fgoclaw-ha-addon)

## Add-ons

### [GoClaw Gateway](./goclaw)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

PostgreSQL multi-tenant AI agent gateway with WebSocket RPC, HTTP API, and
browser automation. Connects to the **TimescaleDB** add-on for PostgreSQL
and optionally to a Redis add-on for caching.

The add-on is equivalent to running `make up WITH_BROWSER=1 WITH_REDIS=1`
in the upstream [`goclaw`](https://github.com/nextlevelbuilder/goclaw)
repository, but delegates PostgreSQL to the TimescaleDB add-on and
(optionally) caching to a Redis add-on — keeping each concern in its own
container.

## Installation

### 1. Add this repository

Click the button above, or manually:

1. Open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add: `https://github.com/imcvampire/goclaw-ha-addon`.

### 2. Install the TimescaleDB add-on (required)

GoClaw needs PostgreSQL. Install the community TimescaleDB add-on which
bundles `pgvector` and is the most widely maintained Postgres option for
Home Assistant OS.

1. **⋮** → **Repositories** → add `https://github.com/expaso/hassos-addons`.
2. Find **PostgreSQL + TimescaleDB** and install it.
3. Before starting, add `goclaw` to the `databases` list in its
   **Configuration** tab:

   ```yaml
   databases:
     - homeassistant
     - goclaw
   timescale_enabled:
     - homeassistant
   ```

4. Start the add-on. Open its **Info** tab and copy the **Hostname**
   (e.g. `a0d7b954-timescaledb`).

### 3. (Optional) Install a Redis add-on

GoClaw works fine with in-memory caching — skip this unless you need
distributed caching. Any add-on exposing Redis on port 6379 works; copy
its hostname from the add-on **Info** page.

### 4. Install GoClaw Gateway

1. In this repository's store entry, click **Install**.
2. On the **Configuration** tab set:

   ```yaml
   postgres_host: a0d7b954-timescaledb   # from step 2
   postgres_port: 5432
   postgres_user: postgres
   postgres_password: homeassistant
   postgres_database: goclaw
   redis_host: ""                         # or your Redis hostname
   redis_port: 6379
   enable_browser: true
   ```

3. Start the add-on.

### 5. First-boot onboarding

On first start the add-on **auto-generates a gateway token** and prints
it in the log:

```
────────────────────────────────────────────────────────────
  Gateway Token (use this to log in to the web dashboard):
  3e625fd87dbcb0b62b03bd534322e85f692e94920a2bca425cf3c1013dcd669f
────────────────────────────────────────────────────────────
```

Copy the token, then open the dashboard (click **Open Web UI** or browse
to `http://<your-ha>:18790`). Log in with **User ID** `system` and the
token. The token is persisted to `/data/goclaw/gateway.token` and
survives restarts. Set the `gateway_token` config option to override it.

## Configuration reference

| Option | Default | Description |
|--------|---------|-------------|
| `postgres_host` | `a0d7b954-timescaledb` | TimescaleDB add-on hostname |
| `postgres_port` | `5432` | PostgreSQL port |
| `postgres_user` | `postgres` | PostgreSQL user |
| `postgres_password` | `homeassistant` | PostgreSQL password |
| `postgres_database` | `goclaw` | Database name (must exist in TimescaleDB) |
| `redis_host` | *(empty)* | Redis add-on hostname. Leave empty to skip. |
| `redis_port` | `6379` | Redis port |
| `enable_browser` | `true` | Start headless Chromium (~200 MB RAM) |
| `gateway_token` | *(empty)* | Auto-generated on first boot if empty |
| `encryption_key` | *(empty)* | AES-256-GCM key for API key encryption (`openssl rand -hex 32`) |
| `log_level` | `info` | `trace`, `debug`, `info`, `warn`, `error` |
| `trace_verbose` | `false` | Verbose LLM call tracing |

See [`goclaw/DOCS.md`](./goclaw/DOCS.md) for the full configuration guide.

## Verification

```bash
curl http://<your-ha>:18790/health
# → {"status":"ok","protocol":3}

curl -H "Authorization: Bearer TOKEN" \
     -H "X-GoClaw-User-Id: system" \
     http://<your-ha>:18790/v1/agents
```

## Local development

A compose-based harness lives in [`goclaw/.tests/`](./goclaw/.tests/) that
simulates the TimescaleDB and Redis add-ons with vanilla containers.

```bash
cd goclaw

# Postgres + GoClaw, no Redis
docker compose -f .tests/docker-compose.test.yaml up --build

# With Redis
cp .tests/test-options-redis.json .tests/test-options.json
docker compose -f .tests/docker-compose.test.yaml --profile redis up --build

# Tear down
docker compose -f .tests/docker-compose.test.yaml --profile redis down -v
```

Dashboard at `http://localhost:18790`. The gateway token is printed in
the compose logs on startup.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Home Assistant                                          │
│                                                          │
│  ┌────────────────────┐   ┌────────────────────────────┐ │
│  │ TimescaleDB add-on │   │ GoClaw Gateway add-on      │ │
│  │ (expaso)           │◄──┤  - Go binary               │ │
│  │  PostgreSQL :5432  │   │  - Embedded web UI :18790  │ │
│  └────────────────────┘   │  - Headless Chromium :9222 │ │
│                           └────────────┬───────────────┘ │
│  ┌────────────────────┐                │                 │
│  │ Redis add-on       │◄───────────────┘ (optional)      │
│  │  (optional)        │                                  │
│  └────────────────────┘                                  │
└──────────────────────────────────────────────────────────┘
```

- The add-on extends the pre-built
  [`ghcr.io/nextlevelbuilder/goclaw:latest`](https://github.com/nextlevelbuilder/goclaw/pkgs/container/goclaw)
  image, adding Chromium, `bash`, and `jq`. No Go or web compilation
  happens at install time.
- PostgreSQL migrations run automatically on each start (`goclaw upgrade`).
- The gateway token is generated once per data volume and survives
  add-on upgrades and restarts.
- Chromium runs as a subprocess inside the add-on container; GoClaw
  connects to it via `ws://localhost:9222`. The external port `9222` is
  disabled by default — enable it only for debugging.

## Troubleshooting

**Add-on won't start — "connection refused" on Postgres**
The TimescaleDB add-on isn't running or the hostname is wrong. Verify in
the TimescaleDB **Info** tab and copy the exact hostname.

**"database does not exist"**
Add `goclaw` to the `databases` list in TimescaleDB configuration, then
restart the TimescaleDB add-on.

**Login shows "Invalid credentials"**
Paste the full 64-character token from the add-on log, with no
leading/trailing whitespace. If you've set `gateway_token` explicitly,
restart the add-on and use that value.

**Chromium crashes / high memory**
Set `enable_browser: false`. Recommended on hosts with < 2 GB RAM.

**pgvector not available**
GoClaw's vector memory requires pgvector. Connect via `psql` and run
`CREATE EXTENSION IF NOT EXISTS vector;`. Non-vector features still work
without it.

## Links

- [GoClaw main repository](https://github.com/nextlevelbuilder/goclaw)
- [TimescaleDB add-on (expaso)](https://github.com/expaso/hassos-addons)
- [Add-on configuration reference](./goclaw/DOCS.md)

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
