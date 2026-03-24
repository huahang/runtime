FROM ubuntu:24.04

RUN apt-get -y update && \
    apt-get -y install \
        build-essential \
        clang \
        curl \
        dumb-init \
        file \
        git \
        golang \
        libssl-dev \
        python-is-python3 \
        python-dev-is-python3 \
        wget \
        zip && \
    apt-get -y upgrade && \
    rm -rf /var/lib/apt/lists/*

# Install nvm and nodejs

RUN git clone --branch v0.40.4 --depth 1 https://github.com/nvm-sh/nvm.git /root/.nvm
RUN set -eux && \
    NODE_VER=v24.14.0 && \
    NODE_PREFIX=/root/.nvm/versions/node/${NODE_VER} && \
    curl -fsSL https://nodejs.org/dist/${NODE_VER}/node-${NODE_VER}.tar.xz -o /tmp/node.tar.xz && \
    tar -xJf /tmp/node.tar.xz -C /tmp && \
    cd /tmp/node-${NODE_VER} && \
    ./configure --prefix=${NODE_PREFIX} --shared-openssl && \
    make -j$(nproc) && \
    make install && \
    bash -c ". /root/.nvm/nvm.sh && nvm alias default ${NODE_VER}" && \
    rm -rf /tmp/node.tar.xz /tmp/node-${NODE_VER}

# Build Go toolchain

RUN mkdir -p /opt && \
    git clone --branch go1.26.1 --depth 1 https://github.com/golang/go /opt/go1.26.1 && \
    git clone --branch go1.24.6 --depth 1 https://github.com/golang/go /opt/go1.24.6 && \
    git clone --branch go1.22.6 --depth 1 https://github.com/golang/go /opt/go1.22.6
RUN cd /opt/go1.22.6/src && ./make.bash
RUN cd /opt/go1.24.6/src && GOROOT_BOOTSTRAP=/opt/go1.22.6 ./make.bash
RUN cd /opt/go1.26.1/src && GOROOT_BOOTSTRAP=/opt/go1.24.6 ./make.bash
RUN rm -rf /opt/go1.22.6 /opt/go1.24.6

# Build v2ray-core and xray-core

RUN git clone --branch v26.2.6 --depth 1 https://github.com/XTLS/Xray-core /root/src/xray-core && \
    git clone --branch v5.47.0 --depth 1 https://github.com/v2fly/v2ray-core /root/src/v2ray-core

RUN if [ "$(arch)" = "x86_64" ]; then \
    cd /root/src/v2ray-core && GOROOT=/opt/go1.26.1 PATH=$GOROOT/bin:$PATH ./release/user-package.sh amd64 nosource tgz; \
    elif [ "$(arch)" = "aarch64" ]; then \
    cd /root/src/v2ray-core && GOROOT=/opt/go1.26.1 PATH=$GOROOT/bin:$PATH ./release/user-package.sh arm64 nosource tgz; \
    fi

RUN mkdir -p /opt/v2ray && \
    if [ "$(arch)" = "x86_64" ]; then \
    tar xf /root/src/v2ray-core/v2ray-custom-amd64-* -C /opt/v2ray; \
    elif [ "$(arch)" = "aarch64" ]; then \
    tar xf /root/src/v2ray-core/v2ray-custom-arm64-* -C /opt/v2ray; \
    fi && \
    rm -rf /root/src/v2ray-core

RUN cd /root/src/xray-core && \
    GOROOT=/opt/go1.26.1 \
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

# Build frp

RUN git clone --branch v0.68.0 --depth 1 https://github.com/fatedier/frp /root/src/frp
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp/web/frpc && npm install && npm run build'
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp/web/frps && npm install && npm run build'
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp && GOROOT=/opt/go1.26.1 PATH=/opt/go1.26.1/bin:$PATH make' && \
    mkdir -p /opt/frp && \
    cp /root/src/frp/bin/frps /opt/frp/frps && \
    cp /root/src/frp/bin/frpc /opt/frp/frpc && \
    rm -rf /root/src/frp

ENTRYPOINT ["dumb-init", "--"]
