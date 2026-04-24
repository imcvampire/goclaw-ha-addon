# Changelog

The addon version follows the `<goclaw version>-<addon version>` format,
e.g. `3.10.0-1` means goclaw `v3.10.0`, addon revision `1`.

## 3.9.2-3

- Install `nodejs` and `npm` in the add-on image so skills that ship a
  `package.json` can resolve their Node dependencies at runtime.
- Reinstall skill dependencies on every add-on start instead of persisting
  the install tree. Install targets (`pip/`, `npm-global/`) stay ephemeral
  under `/app/data/.runtime` so they always match the base image's
  Python/Node ABI after an upgrade, while pip and npm caches now live on
  the persistent `/data/goclaw/.cache` volume so the boot-time reinstall
  is fast. Skills opt in by shipping a top-level `requirements.txt` or
  `package.json`.

## 3.9.2-2

- Fail the add-on start when `goclaw upgrade` fails, instead of
  silently continuing with a possibly inconsistent schema. A failed
  upgrade now prints a clear error and exits non-zero so Home Assistant
  surfaces it.

## 3.9.2-1

- Bump upstream GoClaw to `v3.9.2`
- Adopt `<goclaw version>+<addon version>` versioning scheme
- Pin Dockerfile base image to a specific GoClaw release tag

## 1.0.0

- Initial release
- Equivalent to `make up WITH_BROWSER=1 WITH_REDIS=1`
- Connects to TimescaleDB addon for PostgreSQL
- Optional Redis via external Redis addon
- Headless Chromium for browser automation
- Embedded web dashboard on port 18790
