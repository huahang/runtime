# syntax=docker/dockerfile:1
#
# ghcr.io/huahang/runtime 的多阶段构建。
#
# 阶段说明：
#   builder   — 仅用于引导 Go 工具链并编译 V2Ray 的 Ubuntu 构建环境
#   artifacts — 基于 scratch，导出 V2Ray .tgz，供 CI / 本地提取
#   runtime   — 默认目标；最小化 distroless 镜像，内含已安装的 V2Ray
#
# Ubuntu 工具链与源码编译出的 Go 编译器都不会进入最终镜像。
# 保持 CGO_ENABLED=0，使 V2Ray 静态链接，从而可在
# gcr.io/distroless/static-debian13 上运行。

###############################################################################
# 阶段：builder
#
# 作用：安装构建依赖，从源码引导钉死版本的 Go 工具链，
#       再构建并解压钉死版本的 V2Ray 发布包。
###############################################################################
FROM ubuntu:26.04 AS builder

# 构建依赖说明：
#   curl/wget — Go 的 make.bash 与 V2Ray 发布脚本下载时使用
#   file      — 打包过程中可能用于检查二进制格式
#   git       — 按钉死的 tag 浅克隆 Go 与 V2Ray
#   golang    — Ubuntu 自带的 Go；仅用于引导 /opt/go1.26.5
#   zip       — V2Ray 的 release/user-package.sh 需要
#
# apt-get upgrade 使本层构建环境软件包保持较新；
# 随后删除 apt 列表以减小 builder 层缓存体积。
RUN apt-get -y update && \
    apt-get -y install \
        curl \
        file \
        git \
        golang \
        wget \
        zip && \
    apt-get -y upgrade && \
    rm -rf /var/lib/apt/lists/*

# 通过克隆官方 tag 钉死 Go 版本。深度 1 即可，构建只需该提交，无需完整历史。
#
# 升级此 tag 时，请确认 Ubuntu 自带的 `golang` 仍满足新版本的引导编译器要求，
# 并在同一变更中更新 CLAUDE.md 与 README.md。
RUN mkdir -p /opt && \
    git clone --branch go1.26.5 --depth 1 https://github.com/golang/go /opt/go1.26.5

# 关闭 CGO 编译工具链本身。后续编译 V2Ray 使用的是 /opt/go1.26.5/bin 下的编译器，
# 而不是 Ubuntu 软件包里的 Go。
RUN cd /opt/go1.26.5/src && CGO_ENABLED=0 ./make.bash

# 以同样方式钉死 V2Ray。升级此 tag 时请同步更新 CLAUDE.md 与 README.md。
RUN git clone --branch v5.51.2 --depth 1 https://github.com/v2fly/v2ray-core /root/src/v2ray-core

# 将构建机 uname 架构映射为 V2Ray 打包脚本使用的架构名，然后调用上游发布脚本：
#   nosource — 发布包中不包含源码归档
#   tgz      — 产出 .tgz，而非其他归档格式
#
# GOROOT/PATH 强制使用源码编译的 Go 1.26.5；CGO_ENABLED=0 保证产物静态链接，
# 以便在 distroless/static 运行时中运行。
RUN case "$(arch)" in \
        x86_64) package_arch=amd64 ;; \
        aarch64) package_arch=arm64 ;; \
        *) echo "Unsupported architecture: $(arch)" >&2; exit 1 ;; \
    esac && \
    cd /root/src/v2ray-core && \
    GOROOT=/opt/go1.26.5 \
    PATH=/opt/go1.26.5/bin:$PATH \
    CGO_ENABLED=0 \
    ./release/user-package.sh "$package_arch" nosource tgz

# 收集产物：
#   /artifacts — 单个 .tgz（由 artifacts 阶段 / CI 导出）
#   /opt/v2ray — 解压后的包内容（复制进 runtime 阶段）
#
# 若发布脚本未恰好产出一个匹配的归档则立即失败；
# 随后删除 V2Ray 源码树，避免后续 COPY --from=builder 意外带入多余内容。
RUN case "$(arch)" in \
        x86_64) package_arch=amd64 ;; \
        aarch64) package_arch=arm64 ;; \
        *) echo "Unsupported architecture: $(arch)" >&2; exit 1 ;; \
    esac && \
    mkdir -p /opt/v2ray /artifacts && \
    set -- /root/src/v2ray-core/v2ray-custom-"$package_arch"-* && \
    if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then \
        echo "Expected exactly one V2Ray package for $package_arch" >&2; \
        exit 1; \
    fi && \
    cp "$1" /artifacts/ && \
    tar xf "$1" -C /opt/v2ray && \
    rm -rf /root/src/v2ray-core

###############################################################################
# 阶段：artifacts
#
# 作用：仅暴露生成的 V2Ray .tgz，供 `docker build --target artifacts` / CI 上传。
#       基于 scratch，导出内容只有镜像根目录下的包文件。
###############################################################################
FROM scratch AS artifacts

COPY --from=builder /artifacts/ /

###############################################################################
# 阶段：runtime（默认）
#
# 作用：最终发布镜像。Distroless/static 无 shell、无包管理器，
#       仅适合静态链接二进制。默认以 root 运行，且无 CMD/ENTRYPOINT —
#       需显式调用 v2ray（此时它会成为 PID 1）。
###############################################################################
FROM gcr.io/distroless/static-debian13 AS runtime

# 允许 `docker run ... v2ray ...` 时无需写绝对路径。
ENV PATH=/opt/v2ray

# 只复制解压后的发布内容，不含 Go 工具链、构建依赖或 V2Ray 源码。
# 二进制路径为 /opt/v2ray/v2ray。
COPY --from=builder /opt/v2ray /opt/v2ray

WORKDIR /opt/v2ray
