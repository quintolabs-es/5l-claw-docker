#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${PWD}"

fail_existing() {
  local path="$1"
  echo "Error: target already exists: ${path}" >&2
  exit 1
}

assert_missing() {
  local path="$1"
  if [[ -e "$path" ]]; then
    fail_existing "$path"
  fi
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

TARGET_DOCKER_COMPOSE="${ROOT_DIR}/docker-compose.yml"
TARGET_DOCKERFILE="${ROOT_DIR}/Dockerfile"
TARGET_README="${ROOT_DIR}/README.md"
TARGET_README_ONBOARD="${ROOT_DIR}/README.onboard.md"
TARGET_README_RUN="${ROOT_DIR}/README.run.md"

assert_missing "$TARGET_DOCKER_COMPOSE"
assert_missing "$TARGET_DOCKERFILE"
assert_missing "$TARGET_README"
assert_missing "$TARGET_README_ONBOARD"
assert_missing "$TARGET_README_RUN"

write_file "$TARGET_DOCKER_COMPOSE" <<'EOF'
x-openclaw-env: &openclaw-env
  HOME: /home/node
  TERM: xterm-256color
  OPENCLAW_HOME: /home/node
  OPENCLAW_STATE_DIR: /home/node/.openclaw
  OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN:-missing-openclaw-gateway-token-env-var}

services:
  openclaw-onboard:
    build:
      context: .
      dockerfile: Dockerfile
    environment: *openclaw-env
    init: true
    entrypoint: ["openclaw"]
    command: ["--help"]
    restart: "no"
    volumes:
      - ./openclaw-data/.openclaw:/home/node/.openclaw

  openclaw-gateway:
    build:
      context: .
      dockerfile: Dockerfile
    environment: *openclaw-env
    init: true
    command: ["openclaw", "gateway", "run", "--bind", "lan", "--port", "18789"]
    ports:
      - "18789:18789"
    restart: unless-stopped
    volumes:
      - ./openclaw-data/.openclaw:/home/node/.openclaw

  openclaw-cli:
    build:
      context: .
      dockerfile: Dockerfile
    network_mode: "service:openclaw-gateway"
    cap_drop:
      - NET_RAW
      - NET_ADMIN
    security_opt:
      - no-new-privileges:true
    environment:
      <<: *openclaw-env
      BROWSER: echo
    stdin_open: true
    tty: true
    init: true
    depends_on:
      - openclaw-gateway
    entrypoint: ["openclaw"]
    command: ["--help"]
    restart: "no"
    volumes:
      - ./openclaw-data/.openclaw:/home/node/.openclaw
EOF

write_file "$TARGET_DOCKERFILE" <<'EOF'
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
EOF

write_file "$TARGET_README" <<'EOF'
# OpenClaw Docker Packaging

This repo packages OpenClaw in Docker using the official installer command from the OpenClaw website:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

The container is disposable. Durable OpenClaw state lives in a local project folder so you can rebuild the image and recover the same agent state.

The image build disables installer onboarding with `OPENCLAW_NO_ONBOARD=1` so `docker build` can complete without an interactive TTY. In this Docker setup, `openclaw onboard --install-daemon` is not used; Docker Compose is the process supervisor and starts the gateway with `openclaw gateway run`.

## Why This Exists

Unlike the official Docker setup, which writes config and workspace on the host under `~/.openclaw/` and `~/.openclaw/workspace`, this packaging keeps all OpenClaw state inside this project folder so the environment stays repo-local and can be versioned.

## Initialize

```bash
curl -fsSL https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/init-clow-docker.sh | bash
```

## Runtime

- Persisted state:
  `./openclaw-data/.openclaw`
- Main config:
  `./openclaw-data/.openclaw/openclaw.json`
- Human-edited memory/workspace:
  `./openclaw-data/.openclaw/workspace/`
- Services:
  `openclaw-onboard` is used for pre-start setup commands. `openclaw-gateway` runs continuously. `openclaw-cli` runs on demand after the gateway is up and shares the gateway network.

## Gateway

- Container port:
  `18789`
- Host port:
  `18789 -> 18789`
- WebSocket gateway:
  `ws://localhost:18789/`
- HTTP surface:
  `http://localhost:18789/`

The gateway serves the WebSocket API and the browser Control UI on the same port. The Control UI is the small website bundled with OpenClaw. Open it at `http://localhost:18789/` to operate the local gateway.

Control UI origin policy is configured in `./openclaw-data/.openclaw/openclaw.json`. This setup allowlists only `http://localhost:18789`.

## Runbooks

See [README.onboard.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.onboard.md) for first-time setup.
See [README.run.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.run.md) for normal run commands.
EOF

write_file "$TARGET_README_ONBOARD" <<'EOF'
# OpenClaw Onboard

## Build

```bash
docker compose build
```

## Onboard
Use `openclaw-onboard` for `onboard` and initial config, since `openclaw-cli` is attached to the running gateway network, so it cannot be used for pre-start setup. 

```bash
# run the gateway and bash into the terminal
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint bash openclaw-onboard
# run Onboard
openclaw onboard --mode local --no-install-daemon
## exit the terminal

# back on the host, delete git repo created by openclaw during onboarding
rm -rf ./openclaw-data/.openclaw/workspace/.git

# configure Gateway For Docker from the host
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.mode local
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.bind lan
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json

# OR, use one-off commands only
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw onboard --mode local --no-install-daemon
rm -rf ./openclaw-data/.openclaw/workspace/.git
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.mode local
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.bind lan
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json
```


## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway

# bash into terminal and check Gateway Status
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint bash openclaw-cli
openclaw gateway status --url ws://127.0.0.1:18789 --token "$OPENCLAW_GATEWAY_TOKEN"

# OR one-off command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```

## Open Control UI

```text
http://localhost:18789/
```

## Logs

```bash
docker compose logs -f openclaw-gateway
```
EOF

write_file "$TARGET_README_RUN" <<'EOF'
# OpenClaw Runbook

For first-time setup, use [README.onboard.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.onboard.md).

## Start Gateway

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

The `OPENCLAW_GATEWAY_TOKEN` is the token clients must present to connect to the gateway.

## Logs

```bash
docker compose logs -f openclaw-gateway
```

## Run CLI

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint bash openclaw-cli
```

## Gateway Status

```bash
openclaw gateway status --url ws://127.0.0.1:18789 --token "$OPENCLAW_GATEWAY_TOKEN"

# or one-off command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```

## Doctor

```bash
openclaw doctor

# or one-off command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli doctor
```

## Open Control UI

```text
http://localhost:18789/
```

## State On Host

```bash
ls -la ./openclaw-data/.openclaw
```

## Stop

```bash
docker compose down
```
EOF

echo "Created:"
echo "  docker-compose.yml"
echo "  Dockerfile"
echo "  README.md"
echo "  README.onboard.md"
echo "  README.run.md"
echo
echo "Next:"
echo "  To continue with onboarding, read README.onboard.md"
echo "  and run the onboard steps from that file."
