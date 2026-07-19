FROM node:24-bookworm-slim

ARG GOGCLI_VERSION=v0.12.0
ARG OPENCLAW_VERSION=2026.7.1
ARG TARGETARCH

USER root

# Base system packages required by OpenClaw plus Git/build/runtime utilities.
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

USER node

ENV HOME=/home/node \
    OPENCLAW_HOME=/home/node \
    OPENCLAW_STATE_DIR=/home/node/.openclaw \
    OPENCLAW_NO_ONBOARD=1 \
    OPENCLAW_NO_PROMPT=1 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PATH=/home/node/.local/bin:/home/node/.npm-global/bin:$PATH

WORKDIR /home/node

RUN mkdir -p /home/node/.openclaw /home/node/.local/bin /home/node/.npm-global

# Install OpenClaw through the official installer.
RUN curl -fsSL https://openclaw.ai/install.sh | bash -s -- --version "${OPENCLAW_VERSION}"

USER root

# Install gog CLI for Google integrations used by this template.
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

# Install Playwright-managed Chromium for OpenClaw's built-in browser tool.
## Chromium downloaded by Playwright is stored here inside the image.
RUN mkdir -p /ms-playwright \
 && chown -R node:node /ms-playwright

USER node


RUN set -eux; \
    NPM_ROOT="$(npm root -g)"; \
    PW_CLI="$NPM_ROOT/openclaw/node_modules/playwright-core/cli.js"; \
    if [ ! -f "$PW_CLI" ]; then \
      PW_CLI="$NPM_ROOT/playwright-core/cli.js"; \
    fi; \
    node "$PW_CLI" install chromium

EXPOSE 18789

CMD ["openclaw", "gateway", "run", "--bind", "lan", "--port", "18789"]
