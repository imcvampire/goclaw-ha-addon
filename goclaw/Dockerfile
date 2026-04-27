# Home Assistant addon for GoClaw Gateway
# Extends the pre-built goclaw -full image with Chromium for browser automation.
# The -full variant ships backend + web UI + Python/Node runtimes + skill deps,
# so we only need to add jq (HA option parsing) + Chromium on top.
# PostgreSQL: via TimescaleDB addon. Redis: via external Redis addon.

FROM ghcr.io/nextlevelbuilder/goclaw:v3.11.3-full

RUN apk add --no-cache \
    jq \
    chromium nss freetype harfbuzz ttf-freefont

COPY run.sh /run.sh
RUN chmod +x /run.sh && sed -i 's/\r$//' /run.sh

ENTRYPOINT []
CMD ["/run.sh"]
