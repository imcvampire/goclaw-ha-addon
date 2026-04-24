# Changelog

The addon version follows the `<goclaw version>-<addon version>` format,
e.g. `3.10.0-1` means goclaw `v3.10.0`, addon revision `1`.

## 3.10.0-1

- Bump upstream GoClaw to `v3.10.0`
- Adopt `<goclaw version>+<addon version>` versioning scheme
- Pin Dockerfile base image to a specific GoClaw release tag

## 1.0.0

- Initial release
- Equivalent to `make up WITH_BROWSER=1 WITH_REDIS=1`
- Connects to TimescaleDB addon for PostgreSQL
- Optional Redis via external Redis addon
- Headless Chromium for browser automation
- Embedded web dashboard on port 18790
