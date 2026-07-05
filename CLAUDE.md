# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker container image (`ghcr.io/huahang/runtime`) based on Ubuntu 26.04, packaging pre-built Go toolchains and V2Ray/Xray proxies. The entire project is a single Dockerfile with CI/CD via GitHub Actions.

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

1. **System packages**: All apt dependencies installed in a single `RUN` at the top (build-essential, clang, curl, dumb-init, file, git, golang, python, wget, zip)
2. **Go bootstrap chain**: System Go (from apt) bootstraps Go 1.22.6, which bootstraps Go 1.24.6, which bootstraps Go 1.26.4 (via `GOROOT_BOOTSTRAP`)
3. **V2Ray (v5.51.2)**: Built via `user-package.sh` with architecture detection (`x86_64`/`aarch64`)
4. **Xray (v26.6.27)**: Built from source with `CGO_ENABLED=0`

## Pinned Component Versions

- V2Ray: `v5.51.2` (from `v2fly/v2ray-core`)
- Xray: `v26.6.27` (from `XTLS/Xray-core`)

All Go builds use `/opt/go1.26.4` as `GOROOT`.

## Maintenance Comments

- Keep Go version bootstrapping order unchanged unless all downstream `GOROOT_BOOTSTRAP` references are updated together.
- If V2Ray/Xray versions are bumped in the Dockerfile, update both this file and `README.md` in the same change.
- Preserve architecture handling in V2Ray packaging (`x86_64` and `aarch64`) to avoid breaking multi-arch builds.

## Key Paths in the Image

| Component | Install Path |
|-----------|-------------|
| Go | `/opt/go1.26.4/` |
| V2Ray | `/opt/v2ray/` |
| Xray | `/opt/v2ray/xray` |

## CI/CD

GitHub Actions workflow at `.github/workflows/docker.yml`:
- Triggers on push to `main`, version tags (`v*`), and PRs
- Builds for `linux/amd64` only (ARM64 disabled)
- Pushes to GHCR on push events; PRs build without pushing
- Uses Docker layer caching via `type=gha`

## Conventions

- Commit messages **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`
- Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`
- Examples: `chore(docker): optimize apt installs`, `feat(docker): add arm64 support`
- Version pins are explicit (Go, V2Ray, Xray all pinned to specific tags)
- When updating a component version, update both the Dockerfile `git clone --branch` tag and the README.md version table
- All apt installs consolidated in a single `RUN` at the top of the Dockerfile; later sections only contain source builds
