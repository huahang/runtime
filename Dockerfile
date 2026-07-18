FROM ubuntu:26.04 AS builder

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

RUN mkdir -p /opt && \
    git clone --branch go1.26.5 --depth 1 https://github.com/golang/go /opt/go1.26.5
RUN cd /opt/go1.26.5/src && CGO_ENABLED=0 ./make.bash

RUN git clone --branch v5.51.2 --depth 1 https://github.com/v2fly/v2ray-core /root/src/v2ray-core

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

FROM scratch AS artifacts

COPY --from=builder /artifacts/ /

FROM gcr.io/distroless/static-debian13 AS runtime

ENV PATH=/opt/v2ray

COPY --from=builder /opt/v2ray /opt/v2ray

WORKDIR /opt/v2ray
