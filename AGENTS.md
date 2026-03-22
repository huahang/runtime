# AGENTS.md

Instructions for AI coding agents working in this repository.

## Project Overview

This repository contains a single `Dockerfile` that builds a container image (`ghcr.io/huahang/runtime`) based on Ubuntu 24.04. It packages pre-built Go toolchains, V2Ray/Xray proxies, FRP (Fast Reverse Proxy), and Node.js. There is no application source code — the project is purely an infrastructure image.

## Build Commands

```bash
# Local single-architecture build
docker build -t runtime .

# buildx build (linux/amd64)
docker buildx build --platform linux/amd64 -t runtime .

# Pull pre-built image
docker pull ghcr.io/huahang/runtime:main
```

There is **no Makefile, test suite, or linter**. The project is validated solely by a successful Docker build. To verify changes, run `docker build -t runtime .` and confirm it completes without errors.

## Architecture

The Dockerfile uses a sequential build flow:

1. **System packages**: All apt dependencies installed in a single `RUN` at the top (build-essential, clang, curl, dumb-init, file, git, golang, python, wget, zip)
2. **Node.js bootstrap**: Install NVM and Node.js so npm is available for FRP web UI builds
3. **Go bootstrap chain**: System Go (from apt) bootstraps Go 1.22.6, which bootstraps Go 1.24.6, which bootstraps Go 1.26.1 (via `GOROOT_BOOTSTRAP`)
4. **V2Ray**: Built via `user-package.sh` with architecture detection
5. **Xray**: Built from source with `CGO_ENABLED=0`
6. **FRP**: Web UIs built with npm, binaries built with Go's make

## Pinned Component Versions

| Component | Version | Source |
|-----------|---------|--------|
| V2Ray | v5.47.0 | `v2fly/v2ray-core` |
| Xray | v26.2.6 | `XTLS/Xray-core` |
| FRP | v0.68.0 | `fatedier/frp` |
| NVM | v0.40.4 | `nvm-sh/nvm` |
| Node.js | v24.14.0 | via NVM |
| Go | 1.26.1 (final) | `golang/go` |

All Go builds use `/opt/go1.26.1` as `GOROOT`. NVM commands require `bash -c '. /root/.nvm/nvm.sh && ...'` to source the environment.

## Dockerfile Conventions

- **All apt installs at top**: Consolidate every system package into a single `RUN` at the beginning. This includes build tools and runtime dependencies (e.g., `dumb-init`). Later sections should only contain source builds.
- **`apt-get` pattern**: Use `apt-get -y update && apt-get -y install ... && apt-get -y upgrade && rm -rf /var/lib/apt/lists/*` in one `RUN` to keep layers small.
- **`RUN` chaining**: Use `\` line continuation for multi-line build commands within a single `RUN`. Keep each continuation on its own line with proper indentation.
- **Comments**: One short comment per build stage (e.g., `# Build Go toolchain`). Do not add inline comments.
- **Preserve build order**: Go bootstrapping order must stay unchanged unless all downstream `GOROOT_BOOTSTRAP` references are updated together. Node.js/NVM must come before FRP builds.

## Version Update Process

When bumping a component version:

1. Update the `git clone --branch <tag>` in the Dockerfile
2. Update `README.md` version table
3. Update `CLAUDE.md` pinned versions if present
4. Run `docker build -t runtime .` to verify

## Architecture Handling

V2Ray packaging uses architecture detection (`x86_64`/`aarch64`) via `arch` command. When modifying V2Ray build steps, preserve both code paths. Xray and FRP are built with Go and handle architecture automatically. The CI currently builds only `linux/amd64`.

## CI/CD

GitHub Actions workflow at `.github/workflows/docker.yml`:

- Triggers on push to `main`, version tags (`v*`), and PRs
- Builds for `linux/amd64` only
- Pushes to GHCR on push events; PRs build without pushing
- Uses Docker layer caching via `type=gha`

## Key Paths in the Image

| Component | Install Path |
|-----------|-------------|
| Go | `/opt/go1.26.1/` |
| V2Ray | `/opt/v2ray/` |
| Xray | `/opt/v2ray/xray` |
| FRP | `/opt/frp/frps`, `/opt/frp/frpc` |
| NVM/Node.js | `/root/.nvm/` |

## What to Avoid

- Do not introduce scripts or source files — the project is a single Dockerfile
- Do not change the Go bootstrap chain without updating all `GOROOT_BOOTSTRAP` references
- Do not remove architecture handling from V2Ray packaging
- Do not commit changes unless explicitly asked by the user
- Do not add comments to code unless requested

## Commit Conventions

Commit messages **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]
```

Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`

Examples:
- `chore(docker): optimize apt installs and reduce image layers`
- `feat(docker): add arm64 support for xray build`
- `fix(docker): correct GOROOT_BOOTSTRAP path for go1.24.6`

## Common Tasks

- **Update a dependency version**: Edit the `git clone --branch` tag in Dockerfile, update README.md and CLAUDE.md
- **Add a new system package**: Add it to the apt install block at the top of the Dockerfile
- **Add a new component**: Add a new build section after existing components, following the existing build → copy pattern
- **Debug a build failure**: Run `docker build -t runtime .` locally; the sequential `RUN` instructions make it easy to identify which step failed
