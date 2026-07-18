# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker container image (`ghcr.io/huahang/runtime`) packaging V2Ray. Ubuntu 26.04 and its packaged Go compiler are used only for builds; the runtime is `gcr.io/distroless/static-debian13`. The entire project is a single Dockerfile with CI/CD via GitHub Actions.

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

The Dockerfile uses a multi-stage build flow:

1. **Ubuntu builder**: Installs the build dependencies `curl`, `file`, `git`, `golang`, `wget`, and `zip`; Ubuntu's Go package bootstraps Go 1.26.5 from source.
2. **V2Ray (v5.51.2)**: Clones the pinned tag and runs `release/user-package.sh` with `CGO_ENABLED=0` and explicit `amd64`/`arm64` architecture selection.
3. **Artifact export**: The `artifacts` target exposes the generated V2Ray tar package for local export and CI upload.
4. **Distroless runtime**: The default `runtime` target copies the complete release package from `/opt/v2ray` into `static-debian13`.

## Pinned Component Versions

- Go: `go1.26.5` (from `golang/go`)
- V2Ray: `v5.51.2` (from `v2fly/v2ray-core`)
- Runtime base: `gcr.io/distroless/static-debian13`

Ubuntu's packaged Go compiler is used only to bootstrap `/opt/go1.26.5`. The source-built compiler builds V2Ray, and neither compiler is copied into the final image.

## Maintenance Comments

- When updating Go, verify that Ubuntu's packaged Go compiler satisfies the new version's bootstrap requirement.
- If the Go or V2Ray tag changes in the Dockerfile, update both this file and `README.md` in the same change.
- Preserve the `x86_64`/`aarch64` mapping used by V2Ray's release packaging script so both image architectures continue to build.
- Keep `CGO_ENABLED=0` so the V2Ray binary runs in `distroless/static`.
- Git, download tools, the Go toolchains, and release scripts remain confined to the builder stage.
- The final image has no Go toolchain, Xray, shell, package manager, Git, compiler, or init process.
- The final image uses the default root user and has no default command.

## Key Paths in the Image

| Component | Install Path |
|-----------|-------------|
| V2Ray | `/opt/v2ray/v2ray` |

## CI/CD

GitHub Actions workflow at `.github/workflows/docker.yml`:
- Triggers on push to `main`, version tags (`v*`), and PRs
- Builds natively for both `linux/amd64` and `linux/arm64`
- Uploads the generated tar packages as `v2ray-amd64` and `v2ray-arm64` workflow artifacts
- Pushes the runtime image to GHCR on push events; PRs build without pushing
- Uses Docker layer caching via `type=gha`

## Conventions

- Commit messages **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`
- Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`
- Examples: `chore(docker): optimize apt installs`, `feat(docker): add arm64 support`
- Go and V2Ray are pinned with explicit `git clone --branch` tags.
- When updating either tag, update the corresponding version references in this file and `README.md`.
- Keep build dependencies in the Ubuntu builder stage and copy only `/opt/v2ray` into the runtime stage.
