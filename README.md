# runtime

Distroless container image with V2Ray. Ubuntu 26.04 and its packaged Go compiler are used only during the build; the final image is based on `gcr.io/distroless/static-debian13`.

## Runtime Contents

| Component | Version | Path |
|-----------|---------|------|
| V2Ray | 5.51.2 | `/opt/v2ray/v2ray` |

## Build Notes

- The Ubuntu builder installs the build dependencies `curl`, `file`, `git`, `golang`, `wget`, and `zip`.
- Ubuntu's packaged Go compiler bootstraps the pinned Go 1.26.5 toolchain from source; that toolchain then builds V2Ray v5.51.2.
- V2Ray is cloned from its pinned Git tag and packaged with `release/user-package.sh`, `CGO_ENABLED=0`, and explicit `amd64`/`arm64` architecture selection.
- The generated tar package is retained in the `artifacts` target, while its contents are copied into the final distroless stage.
- The final image uses the default root user and contains no Go toolchain, Xray, shell, package manager, compiler, Git, or init process.
- There is no default command. Run `v2ray` explicitly; it runs directly as PID 1.

## Pulling the Image

The image is a multi-arch manifest supporting both `amd64` and `arm64`. Docker automatically selects the correct variant for your host.

```bash
docker pull ghcr.io/huahang/runtime:main
```

## Running

```bash
docker run --rm ghcr.io/huahang/runtime:main v2ray version
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

## Package Artifacts

Each workflow run uploads the generated V2Ray tar packages as separate `v2ray-amd64` and `v2ray-arm64` artifacts. Tag builds also attach both tar packages to the matching GitHub Release. To export a package locally:

```bash
docker buildx build \
  --platform linux/amd64 \
  --target artifacts \
  --output type=local,dest=dist .
```

## CI/CD

A GitHub Actions workflow builds the runtime image and V2Ray package artifacts on:

- Push to `main`
- Tags matching `v*`

Pull requests trigger a build without pushing.

Images are built natively on both `amd64` (`ubuntu-latest`) and `arm64` (`ubuntu-24.04-arm`) runners in parallel, then merged into a single multi-arch manifest.
