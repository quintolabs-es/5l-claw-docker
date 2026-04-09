FROM node:24-bookworm-slim

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
