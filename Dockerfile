FROM ubuntu:24.04

# Install nvm and nodejs

RUN apt-get -y update
RUN apt-get -y install build-essential
RUN apt-get -y install clang
RUN apt-get -y install curl
RUN apt-get -y install git
RUN apt-get -y install python-is-python3
RUN apt-get -y install python-dev-is-python3
RUN apt-get -y install wget
RUN apt-get -y upgrade

RUN git clone --branch v0.40.4 --depth 1 https://github.com/nvm-sh/nvm.git /root/.nvm
RUN bash -c '. /root/.nvm/nvm.sh && nvm install -s v24.14.0'

# Install dependencies and build Go

RUN apt-get -y update
RUN apt-get -y install golang
RUN apt-get -y upgrade

RUN mkdir -p /opt
RUN git clone --branch go1.26.1 --depth 1 https://github.com/golang/go /opt/go1.26.1
RUN git clone --branch go1.24.6 --depth 1 https://github.com/golang/go /opt/go1.24.6
RUN git clone --branch go1.22.6 --depth 1 https://github.com/golang/go /opt/go1.22.6
RUN cd /opt/go1.22.6/src && ./make.bash
RUN cd /opt/go1.24.6/src && GOROOT_BOOTSTRAP=/opt/go1.22.6 ./make.bash
RUN cd /opt/go1.26.1/src && GOROOT_BOOTSTRAP=/opt/go1.24.6 ./make.bash

# Install dependencies and build v2ray-core

RUN apt-get -y update
RUN apt-get -y install ca-certificates
RUN apt-get -y install curl
RUN apt-get -y install zip
RUN apt-get -y upgrade

RUN git clone --branch v26.2.6 --depth 1 https://github.com/XTLS/Xray-core /root/src/xray-core
RUN git clone --branch v5.47.0 --depth 1 https://github.com/v2fly/v2ray-core /root/src/v2ray-core

RUN if [ "$(arch)" = "x86_64" ]; then \
    cd /root/src/v2ray-core && GOROOT=/opt/go1.26.1 PATH=$GOROOT/bin:$PATH ./release/user-package.sh amd64 nosource tgz; \
    elif [ "$(arch)" = "aarch64" ]; then \
    cd /root/src/v2ray-core && GOROOT=/opt/go1.26.1 PATH=$GOROOT/bin:$PATH ./release/user-package.sh arm64 nosource tgz; \
    fi

RUN mkdir -p /opt/v2ray

RUN if [ "$(arch)" = "x86_64" ]; then \
    tar xf /root/src/v2ray-core/v2ray-custom-amd64-* -C /opt/v2ray; \
    elif [ "$(arch)" = "aarch64" ]; then \
    tar xf /root/src/v2ray-core/v2ray-custom-arm64-* -C /opt/v2ray; \
    fi

# Install dependencies and build xray-core

RUN apt-get -y update
RUN apt-get -y install file
RUN apt-get -y upgrade

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
    ./main
RUN cp /root/src/xray-core/xray /opt/v2ray/xray

# Install dependencies and build frp

RUN git clone --branch v0.68.0 --depth 1 https://github.com/fatedier/frp /root/src/frp
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp/web/frpc && npm install'
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp/web/frpc && npm run build'
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp/web/frps && npm install'
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp/web/frps && npm run build'
RUN bash -c '. /root/.nvm/nvm.sh && cd /root/src/frp && GOROOT=/opt/go1.26.1 PATH=/opt/go1.26.1/bin:$PATH make'
RUN mkdir -p /opt/frp
RUN cp /root/src/frp/bin/frps /opt/frp/frps
RUN cp /root/src/frp/bin/frpc /opt/frp/frpc

# Install dumb-init

RUN apt-get -y update
RUN apt-get -y install dumb-init
RUN apt-get -y upgrade

ENTRYPOINT ["dumb-init", "--"]
