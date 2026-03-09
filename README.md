# runtime

Multi-architecture Docker container image with pre-built Go toolchains, V2Ray/Xray proxies, and Node.js runtime, based on Ubuntu 24.04.

## What's Included

| Component | Version | Path |
|-----------|---------|------|
| Go (bootstrap) | 1.22.6 | `/opt/go1.22.6/` |
| Go | 1.24.6 | `/opt/go1.24.6/` |
| Go | 1.26.1 | `/opt/go1.26.1/` |
| V2Ray | 5.46.0 | `/opt/v2ray/` |
| Xray | 26.2.6 | `/opt/v2ray/xray` |
| Node.js | LTS (via NVM 0.40.4) | managed by NVM |

## Pulling the Image

```bash
docker pull ghcr.io/huahang/runtime:main
```

## Building Locally

```bash
# Single architecture
docker build -t runtime .

# Multi-architecture
docker buildx build --platform linux/amd64,linux/arm64 -t runtime .
```

## CI/CD

A GitHub Actions workflow builds and pushes multi-arch images to GHCR on:

- Push to `main`
- Tags matching `v*`

Pull requests trigger a build without pushing.