# runtime

Docker container image with pre-built Go toolchains, V2Ray/Xray proxies, FRP (Fast Reverse Proxy), and Node.js runtime, based on Ubuntu 24.04.

## What's Included

| Component | Version | Path |
|-----------|---------|------|
| Go | 1.26.1 | `/opt/go1.26.1/` |
| V2Ray | 5.47.0 | `/opt/v2ray/` |
| Xray | 26.2.6 | `/opt/v2ray/xray` |
| FRP | 0.68.0 | `/opt/frp/frps`, `/opt/frp/frpc` |
| Node.js | 24.14.0 (via NVM 0.40.4) | managed by NVM |

## Build Notes

- Node.js is installed early in the Dockerfile because FRP web UIs are built with npm before final FRP binaries are packaged.
- Go 1.22.6 and 1.24.6 are intermediate bootstrap toolchains; only the final Go 1.26.1 remains in the image.
- V2Ray release artifacts are produced with architecture-aware packaging (`amd64` and `arm64`) and extracted into `/opt/v2ray`.
- Xray is compiled with `CGO_ENABLED=0` for static, portable binaries.
- Runtime process handling uses `dumb-init` as entrypoint for cleaner signal forwarding in containers.

## Pulling the Image

```bash
docker pull ghcr.io/huahang/runtime:main
```

## Building Locally

```bash
# Single architecture
docker build -t runtime .

# With buildx
docker buildx build --platform linux/amd64 -t runtime .
```

## CI/CD

A GitHub Actions workflow builds and pushes images to GHCR on:

- Push to `main`
- Tags matching `v*`

Pull requests trigger a build without pushing.