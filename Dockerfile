FROM ubuntu:26.04

RUN apt-get -y update && \
    apt-get -y install \
        build-essential \
        clang \
        curl \
        dumb-init \
        file \
        git \
        golang \
        python-is-python3 \
        python-dev-is-python3 \
        wget \
        zip && \
    apt-get -y upgrade && \
    rm -rf /var/lib/apt/lists/*

# Build Go toolchain

# Go 1.26.x requires Go >= 1.24.6 for bootstrap; Ubuntu 26.04's golang
# package ships Go 1.26, so the system Go bootstraps Go 1.26.4 directly.
RUN mkdir -p /opt && \
    git clone --branch go1.26.4 --depth 1 https://github.com/golang/go /opt/go1.26.4
RUN cd /opt/go1.26.4/src && ./make.bash

# Build v2ray-core and xray-core

RUN git clone --branch v26.6.27 --depth 1 https://github.com/XTLS/Xray-core /root/src/xray-core && \
    git clone --branch v5.51.2 --depth 1 https://github.com/v2fly/v2ray-core /root/src/v2ray-core

RUN if [ "$(arch)" = "x86_64" ]; then \
    cd /root/src/v2ray-core && GOROOT=/opt/go1.26.4 PATH=$GOROOT/bin:$PATH ./release/user-package.sh amd64 nosource tgz; \
    elif [ "$(arch)" = "aarch64" ]; then \
    cd /root/src/v2ray-core && GOROOT=/opt/go1.26.4 PATH=$GOROOT/bin:$PATH ./release/user-package.sh arm64 nosource tgz; \
    fi

RUN mkdir -p /opt/v2ray && \
    if [ "$(arch)" = "x86_64" ]; then \
    tar xf /root/src/v2ray-core/v2ray-custom-amd64-* -C /opt/v2ray; \
    elif [ "$(arch)" = "aarch64" ]; then \
    tar xf /root/src/v2ray-core/v2ray-custom-arm64-* -C /opt/v2ray; \
    fi && \
    rm -rf /root/src/v2ray-core

RUN cd /root/src/xray-core && \
    GOROOT=/opt/go1.26.4 \
    PATH=$GOROOT/bin:$PATH \
    CGO_ENABLED=0 \
    go build -o xray \
    -trimpath \
    -buildvcs=false \
    -gcflags="all=-l=4" \
    -ldflags="-X github.com/xtls/xray-core/core.build=REPLACE -s -w -buildid=" \
    -v \
    ./main && \
    cp xray /opt/v2ray/xray && \
    rm -rf /root/src/xray-core

ENTRYPOINT ["dumb-init", "--"]
