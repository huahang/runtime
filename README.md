# runtime

带 V2Ray 的 Distroless 镜像. 构建时使用 Ubuntu 26.04 和系统自带的 Go, 最终镜像基于 `gcr.io/distroless/static-debian13`.

## 镜像内容

| 组件 | 版本 | 路径 |
|------|------|------|
| V2Ray | 5.54.2 | `/opt/v2ray/v2ray` |

## 构建说明

- 构建环境会安装 `curl`, `file`, `git`, `golang`, `wget` 和 `zip`.
- 系统自带的 Go 先从源码引导出固定的 Go 1.27.1, 再用它编译 V2Ray v5.54.2.
- V2Ray 按固定的 Git tag 克隆, 由 `release/user-package.sh` 打包. 编译时设置 `CGO_ENABLED=0`, 并按 `amd64` 或 `arm64` 选择架构.
- 生成的 tar 包留在 `artifacts` 目标中, 解压后的内容会复制进最终的 distroless 阶段.
- 最终镜像以默认的 root 用户运行, 其中没有 Go 工具链, Xray, shell, 包管理器, 编译器, Git 和 init 进程.
- 镜像没有默认命令. 需要自己运行 `v2ray`, 这时它就是 PID 1.

## 拉取

镜像同时提供 `amd64` 和 `arm64`. Docker 会按宿主机架构自动选择.

```bash
docker pull ghcr.io/huahang/runtime:main
```

## 运行

```bash
docker run --rm ghcr.io/huahang/runtime:main v2ray version
```

## 在本地构建

```bash
# 本机架构
docker build -t runtime .

# 构建 amd64
docker buildx build --platform linux/amd64 -t runtime .

# 构建 arm64
docker buildx build --platform linux/arm64 -t runtime .
```

## 导出安装包

每次工作流运行都会把 V2Ray 的 tar 包分成 `v2ray-amd64` 和 `v2ray-arm64` 两个 artifact 上传. 打 tag 的构建还会把这两个包附到对应的 GitHub Release. 本地可以这样导出:

```bash
docker buildx build \
  --platform linux/amd64 \
  --target artifacts \
  --output type=local,dest=dist .
```

## 自动构建与发布

GitHub Actions 会在下面两种情况构建运行时镜像和 V2Ray 安装包:

- 推送到 `main`
- 推送匹配 `v*` 的 tag

Pull Request 会触发构建, 但不会推送镜像.

`amd64` (`ubuntu-latest`) 和 `arm64` (`ubuntu-24.04-arm`) 在各自的 runner 上并行构建, 完成后合并成一份多架构镜像.
