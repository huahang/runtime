# AGENTS.md

这份文件说明在本仓库里改代码时要遵守的约定.

## 沟通语言

本项目主要使用简体中文沟通. 讨论, 说明和答复默认都用简体中文.

标点用半角: 逗号, 句号, 冒号, 分号, 问号, 叹号, 括号和连字符都写成 ASCII. 列举时用半角逗号, 不用顿号.

## 项目是什么

`ghcr.io/huahang/runtime` 是一份带 V2Ray 的容器镜像. 构建用 Ubuntu 26.04 和系统自带的 Go, 运行时基础镜像是 `gcr.io/distroless/static-debian13`. 仓库里主要就是一份 Dockerfile, 发布由 GitHub Actions 完成.

## 怎么构建

```bash
# 本机架构
docker build -t runtime .

# 指定架构
docker buildx build --platform linux/amd64 -t runtime .

# 拉取已发布的镜像
docker pull ghcr.io/huahang/runtime:main
```

仓库没有 Makefile, 也没有测试和 lint. 要验证改动, 就构建这张镜像.

## 镜像怎么拼出来

Dockerfile 分四段:

1. **Ubuntu 构建环境**: 安装 `curl`, `file`, `git`, `golang`, `wget`, `zip`. 系统自带的 Go 只负责从源码引导出 Go 1.27.1.
2. **V2Ray (v5.54.2)**: 按钉死的 tag 克隆源码, 再跑 `release/user-package.sh`. 编译时设置 `CGO_ENABLED=0`, 并按 `amd64` 或 `arm64` 选择架构.
3. **导出安装包**: `artifacts` 目标里只有打好的 V2Ray tar 包, 本地可以取出来, CI 也会把它上传.
4. **Distroless 运行时**: 默认目标 `runtime` 把 `/opt/v2ray` 下的完整发布内容复制进 `static-debian13`.

## 钉死的版本

- Go: `go1.27.1` (来自 `golang/go`)
- V2Ray: `v5.54.2` (来自 `v2fly/v2ray-core`)
- 运行时基础镜像: `gcr.io/distroless/static-debian13`

Ubuntu 自带的 Go 只用来引导 `/opt/go1.27.1`. 编译 V2Ray 用的是这份从源码编出来的编译器. 两份编译器都留在构建阶段, 不会进最终镜像.

## 改版本时

- 升级 Go 之前, 先确认 Ubuntu 自带的 Go 还满足新版本的引导要求.
- Dockerfile 里的 Go 或 V2Ray tag 一旦改动, 同一次提交里把本文件和 `README.md` 的版本一起改掉.
- 保留发布脚本用的 `x86_64` / `aarch64` 架构映射, 这样 amd64 和 arm64 都能继续构建.
- 保持 `CGO_ENABLED=0`, V2Ray 才能在 `distroless/static` 里运行.
- Git, 下载工具, Go 工具链和发布脚本只放在构建阶段.
- 最终镜像里不要放 Go 工具链, Xray, shell, 包管理器, Git, 编译器或 init 进程.
- 最终镜像继续用默认的 root 用户, 不设置默认命令.

## 镜像里的路径

| 组件 | 路径 |
|------|------|
| V2Ray | `/opt/v2ray/v2ray` |

## CI

工作流文件是 `.github/workflows/docker.yml`.

- 推送到 `main`, 打上 `v*` tag, 或打开 Pull Request 时触发
- 在 `linux/amd64` 和 `linux/arm64` 上各自原生构建
- 把 tar 包上传成两个 workflow artifact: `v2ray-amd64` 和 `v2ray-arm64`
- 打 `v*` tag 时创建或更新 GitHub Release, 并附上这两个 tar 包
- 只有 push 会把镜像推到 GHCR; Pull Request 只构建
- Docker 层缓存使用 `type=gha`

## 提交约定

- 提交说明遵循 [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`
- 常用 type: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`
- 示例: `chore(docker): optimize apt installs`, `feat(docker): add arm64 support`
- Go 和 V2Ray 都用 `git clone --branch` 钉死到具体 tag
- 构建依赖留在 Ubuntu 构建阶段; 运行时阶段只复制 `/opt/v2ray`
