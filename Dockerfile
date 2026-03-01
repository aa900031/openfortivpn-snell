FROM debian:bookworm-slim AS builder-openfortivpn

ARG OPENFORTIVPN_VERSION=v1.24.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ppp \
        automake \
        autoconf \
        g++ \
        gcc \
        make \
        pkg-config \
        libssl-dev \
    && mkdir -p "/usr/src/openfortivpn" \
    && cd "/usr/src/openfortivpn" \
    && curl -Ls https://github.com/adrienverge/openfortivpn/archive/${OPENFORTIVPN_VERSION}.tar.gz \
        | tar xz --strip-components 1 \
    && aclocal \
    && autoconf \
    && automake --add-missing \
    && ./configure --prefix=/usr --sysconfdir=/etc \
    && make \
    && make install

FROM debian:bookworm-slim AS builder-snell

ARG SNELL_VERSION=v5.0.1
ARG TARGETARCH

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
    && mkdir -p /tmp/snell-download \
    && cd /tmp/snell-download \
    && case "${TARGETARCH}" in \
        amd64) SNELL_ARCH="amd64" ;; \
        386) SNELL_ARCH="i386" ;; \
        arm64) SNELL_ARCH="aarch64" ;; \
        arm) SNELL_ARCH="armv7l" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -Ls https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${SNELL_ARCH}.zip -o snell-server.zip \
    && unzip -q snell-server.zip \
    && mv snell-server /usr/bin/snell-server \
    && chmod +x /usr/bin/snell-server \
    && cd / \
    && rm -rf /tmp/snell-download

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        openssl \
        ppp \
        bash \
        supervisor \
        oathtool \
        curl \
        iproute2 \
        libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder-openfortivpn /usr/bin/openfortivpn /usr/bin/openfortivpn
COPY --from=builder-snell /usr/bin/snell-server /usr/bin/snell-server
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENV \
    SNELL_PSK= \
    SNELL_OBFS=tls \
    SNELL_PORT=12543 \
    SNELL_HOST=0.0.0.0 \
    OTP_SECRET= \
    OTP_ARGS= \
    OTP_IS_OPENFORTIVPN_PASSWORD=true \
    OPENFORTIVPN_ARGS= \
    OPENFORTIVPN_HOSTNAME= \
    OPENFORTIVPN_USERNAME= \
    OPENFORTIVPN_PASSWORD= \
    OPENFORTIVPN_EXTRA_ARGS= \
    OPENFORTIVPN_PASSWORD_STDIN=true

WORKDIR /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "supervisor" ]