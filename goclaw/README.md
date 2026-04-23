# Home Assistant Add-on: GoClaw Gateway

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

_PostgreSQL multi-tenant AI agent gateway with WebSocket RPC, HTTP API, and
headless browser automation._

## About

Runs the [GoClaw Gateway](https://github.com/nextlevelbuilder/goclaw) as a
Home Assistant add-on. Equivalent to `make up WITH_BROWSER=1 WITH_REDIS=1`
in the upstream repository, but delegates PostgreSQL to the
[TimescaleDB add-on](https://github.com/expaso/hassos-addons) and
(optionally) caching to a Redis add-on.

See the repository [`README.md`](../README.md) for installation and the
full configuration guide, or [`DOCS.md`](./DOCS.md) for the in-Supervisor
documentation tab.

## Ports

- `18790/tcp` — Gateway API + web dashboard
- `9222/tcp` — Chrome DevTools Protocol (optional, disabled by default)

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
