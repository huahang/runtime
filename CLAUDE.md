# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker container image (`ghcr.io/huahang/runtime`) based on Ubuntu 24.04, packaging pre-built Go toolchains, V2Ray/Xray proxies, FRP (Fast Reverse Proxy), and Node.js. The entire project is a single Dockerfile with CI/CD via GitHub Actions.

## Build Commands

```bash
# Local build (single architecture)
docker build -t runtime .

# With buildx
docker buildx build --platform linux/amd64 -t runtime .

# Pull pre-built image
docker pull ghcr.io/huahang/runtime:main
```

There is no Makefile, test suite, or linter — the project is a pure Dockerfile build.

## Architecture

The Dockerfile uses a sequential build flow:

1. **Node.js bootstrap**: Install NVM v0.40.4 and Node.js v24.14.0 first (source build) so npm is available for FRP web UI builds
2. **Go bootstrap chain**: System Go → Go 1.22.6 → Go 1.24.6 → Go 1.26.1 (each version bootstraps the next via `GOROOT_BOOTSTRAP`)
3. **V2Ray (v5.47.0)**: Built via `user-package.sh` with architecture detection (`x86_64`/`aarch64`)
4. **Xray (v26.2.6)**: Built from source with `CGO_ENABLED=0`
5. **FRP (v0.68.0)**: Web UIs built with npm, binaries built with Go's make
6. **dumb-init**: Installed from apt, set as `ENTRYPOINT` for proper signal forwarding to child processes

## Pinned Component Versions

- V2Ray: `v5.47.0` (from `v2fly/v2ray-core`)
- Xray: `v26.2.6` (from `XTLS/Xray-core`)
- FRP: `v0.68.0` (from `fatedier/frp`)
- NVM: `v0.40.4` (from `nvm-sh/nvm`)
- Node.js: `v24.14.0` (installed via NVM)

All Go builds use `/opt/go1.26.1` as `GOROOT`. NVM commands require `bash -c '. /root/.nvm/nvm.sh && ...'` to source the NVM environment.

## Maintenance Comments

- Keep the Node.js/NVM block before FRP build steps because FRP web assets require npm during image build.
- Keep Go version bootstrapping order unchanged unless all downstream `GOROOT_BOOTSTRAP` references are updated together.
- If V2Ray/FRP versions are bumped in the Dockerfile, update both this file and `README.md` in the same change.
- Preserve architecture handling in V2Ray packaging (`x86_64` and `aarch64`) to avoid breaking multi-arch builds.

## Key Paths in the Image

| Component | Install Path |
|-----------|-------------|
| Go versions | `/opt/go1.22.6/`, `/opt/go1.24.6/`, `/opt/go1.26.1/` |
| V2Ray | `/opt/v2ray/` |
| Xray | `/opt/v2ray/xray` |
| FRP | `/opt/frp/frps`, `/opt/frp/frpc` |
| NVM/Node.js | `/root/.nvm/` |
| Build sources | `/root/src/` |

## CI/CD

GitHub Actions workflow at `.github/workflows/docker.yml`:
- Triggers on push to `main`, version tags (`v*`), and PRs
- Builds for `linux/amd64` only (ARM64 disabled)
- Pushes to GHCR on push events; PRs build without pushing
- Uses Docker layer caching via `type=gha`

## Conventions

- Commit messages are in Chinese
- Version pins are explicit (Go, V2Ray, Xray, NVM, Node.js, FRP all pinned to specific tags)
- When updating a component version, update both the Dockerfile `git clone --branch` tag and the README.md version table
