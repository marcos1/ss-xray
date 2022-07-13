FROM ghcr.io/linuxserver/baseimage-alpine:edge

ARG BUILD_DATE
ARG VERSION
ARG SHADOWSOCKSXRAY_RELEASE

LABEL build_version="version:- ${VERSION} Build-date:- ${BUILD_DATE}"

LABEL maintainer="marcos"

# enviroment settings
ARG XRAY_VERSION="master"

RUN \
    echo "*** installing packages ***" && \
    apk add -U --upgrade --no-cache \
        curl \
        bash \
        git && \
        git clone --recursive https://github.com/shadowsocks/shadowsocks-libev.git /tmp/repo

RUN set -ex \
 # Build environment setup
 && apk add --no-cache --virtual .build-deps \
      autoconf \
      automake \
      build-base \
      c-ares-dev \
      libcap \
      libev-dev \
      libtool \
      libsodium-dev \
      linux-headers \
      mbedtls-dev \
      pcre-dev \
 # Build & install
 && cd /tmp/repo \
 && ./autogen.sh \
 && ./configure --prefix=/usr --disable-documentation \
 && make install \
 && ls /usr/bin/ss-* | xargs -n1 setcap cap_net_bind_service+ep \
 && apk del .build-deps \
 # Runtime dependencies setup
 && apk add --no-cache \
      ca-certificates \
      rng-tools \
      tzdata \
      $(scanelf --needed --nobanner /usr/bin/ss-* \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u) \
 && rm -rf /tmp/repo


RUN \
    set -ex \
        && export arch=$(uname -m) \
        && if [ "${arch}" = "x86_64" ]; then export arch=amd64; fi \
        && if [ "${arch}" = "armv7l" ]; then export arch=arm; fi \
        && if [ "${arch}" = "aarch64" ]; then export arch=arm64; fi && \
        xrayurl=$(curl -s \
            https://api.github.com/repos/teddysun/xray-plugin/releases/latest \
            | grep "browser_download_url.*gz" \
            | cut -d : -f 2,3 \
            | tr -d \" \
            | grep $arch \
            | grep linux) && \
            echo "*** downloading xray ***" && \
            wget -q $xrayurl && \
            echo "*** exracting xray ***" && \
            tar -xf xray-*.tar.gz && \
            echo "*** renaming xray ***" && \
            mv xray*_$arch xray-plugin && \
            echo "*** moving xray to /usr/bin ***" && \
            mv xray-plugin /usr/bin/

ENV SERVER_PORT 1080
ENV SERVER_ADDR 0.0.0.0
ENV PASSWORD password
ENV METHOD chacha20-ietf-poly1305
ENV PLUGIN xray-plugin
ENV PLUGIN_OPTS server
ENV ARGS=

# copy local file
COPY root/ /

EXPOSE $SERVER_PORT
