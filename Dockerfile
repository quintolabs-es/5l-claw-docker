FROM node:24-bookworm-slim

ARG GOGCLI_VERSION=v0.12.0
ARG TARGETARCH

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    cmake \
    curl \
    g++ \
    git \
    make \
    openssh-client \
    python3 \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
      amd64|arm64) ;; \
      *) echo "Unsupported TARGETARCH: $arch" >&2; exit 1 ;; \
    esac; \
    version="${GOGCLI_VERSION#v}"; \
    asset="gogcli_${version}_linux_${arch}.tar.gz"; \
    curl -fsSL "https://github.com/steipete/gogcli/releases/download/${GOGCLI_VERSION}/checksums.txt" -o /tmp/gogcli-checksums.txt; \
    curl -fsSL "https://github.com/steipete/gogcli/releases/download/${GOGCLI_VERSION}/${asset}" -o /tmp/gogcli.tar.gz; \
    checksum="$(awk '/ '"${asset}"'$/ { print $1 }' /tmp/gogcli-checksums.txt)"; \
    test -n "$checksum"; \
    printf '%s  %s\n' "$checksum" /tmp/gogcli.tar.gz | sha256sum -c -; \
    tar -xzf /tmp/gogcli.tar.gz -C /tmp gog; \
    install -m 0755 /tmp/gog /usr/local/bin/gog; \
    rm -f /tmp/gog /tmp/gogcli.tar.gz /tmp/gogcli-checksums.txt

USER node

ENV HOME=/home/node \
    OPENCLAW_HOME=/home/node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_NO_ONBOARD=1 \
    OPENCLAW_NO_PROMPT=1 \
    PATH=/home/node/.local/bin:/home/node/.npm-global/bin:$PATH

WORKDIR /home/node

RUN mkdir -p /home/node/.openclaw /home/node/.local/bin /home/node/.npm-global

RUN curl -fsSL https://openclaw.ai/install.sh | bash

EXPOSE 18789

CMD ["openclaw", "gateway", "run", "--bind", "lan", "--port", "18789"]
