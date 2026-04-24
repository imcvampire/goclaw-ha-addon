# Home Assistant addon for GoClaw Gateway
# Extends the pre-built goclaw image with Chromium for browser automation.
# Equivalent to: make up WITH_BROWSER=1 WITH_REDIS=1
# PostgreSQL: via TimescaleDB addon. Redis: via external Redis addon.

FROM ghcr.io/nextlevelbuilder/goclaw:v3.9.2

RUN apk add --no-cache \
    bash jq \
    chromium nss freetype harfbuzz ttf-freefont \
    nodejs npm

COPY run.sh /run.sh
RUN chmod +x /run.sh && sed -i 's/\r$//' /run.sh

ENTRYPOINT []
CMD ["/run.sh"]
