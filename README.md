# runtime

Docker container image with pre-built Go toolchains and V2Ray/Xray proxies, based on Ubuntu 26.04.

## What's Included

| Component | Version | Path |
|-----------|---------|------|
| Go | 1.26.4 | `/opt/go1.26.4/` |
| V2Ray | 5.51.2 | `/opt/v2ray/` |
| Xray | 26.6.27 | `/opt/v2ray/xray` |

## Build Notes

- Go 1.26.4 is bootstrapped directly from the Ubuntu 26.04 system Go (1.26 series), which satisfies the Go >= 1.24.6 bootstrap requirement; no intermediate toolchains are built.
- V2Ray release artifacts are produced with architecture-aware packaging (`amd64` and `arm64`) and extracted into `/opt/v2ray`.
- Xray is compiled with `CGO_ENABLED=0` for static, portable binaries.
- Runtime process handling uses `dumb-init` as entrypoint for cleaner signal forwarding in containers.

## Pulling the Image

The image is a multi-arch manifest supporting both `amd64` and `arm64`. Docker automatically selects the correct variant for your host.

```bash
docker pull ghcr.io/huahang/runtime:main
```

## Building Locally

```bash
# Single architecture (native)
docker build -t runtime .

# amd64 with buildx
docker buildx build --platform linux/amd64 -t runtime .

# arm64 with buildx
docker buildx build --platform linux/arm64 -t runtime .
```

## CI/CD

A GitHub Actions workflow builds and pushes images to GHCR on:

- Push to `main`
- Tags matching `v*`

Pull requests trigger a build without pushing.

Images are built natively on both `amd64` (`ubuntu-latest`) and `arm64` (`ubuntu-24.04-arm`) runners in parallel, then merged into a single multi-arch manifest. Tags matching `v*` also create a GitHub Release containing V2Ray packages for `x86_64` and `aarch64`.
