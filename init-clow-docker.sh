#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${PWD}"
RAW_BASE_URL="https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main"
GATEWAY_PORT="18789"

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

usage() {
  cat <<'EOF'
Usage: init-clow-docker.sh [--port <port>]
EOF
}

validate_port() {
  local port="$1"

  if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    echo "Error: --port must be a number" >&2
    exit 1
  fi

  if (( port < 1 || port > 65535 )); then
    echo "Error: --port must be between 1 and 65535" >&2
    exit 1
  fi
}

download_file() {
  local remote_name="$1"
  local target_path="$2"
  mkdir -p "$(dirname "$target_path")"
  curl -fsSL "${RAW_BASE_URL}/${remote_name}" -o "$target_path"
}

rewrite_port_in_file() {
  local path="$1"
  PORT="$GATEWAY_PORT" perl -0pi -e 's/18789/$ENV{PORT}/g' "$path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      if [[ $# -lt 2 ]]; then
        echo "Error: --port requires a value" >&2
        usage >&2
        exit 1
      fi
      GATEWAY_PORT="$2"
      shift 2
      ;;
    --port=*)
      GATEWAY_PORT="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

validate_port "$GATEWAY_PORT"

TARGET_DOCKER_COMPOSE="${ROOT_DIR}/docker-compose.yml"
TARGET_DOCKERFILE="${ROOT_DIR}/Dockerfile"
TARGET_README="${ROOT_DIR}/README.md"
TARGET_README_CLAW="${ROOT_DIR}/README.claw.md"
TARGET_README_ONBOARD="${ROOT_DIR}/README.claw-onboard.md"
TARGET_README_RUN="${ROOT_DIR}/README.claw-run.md"

assert_missing "$TARGET_DOCKER_COMPOSE"
assert_missing "$TARGET_DOCKERFILE"
assert_missing "$TARGET_README"
assert_missing "$TARGET_README_CLAW"
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
    stdin_open: true
    tty: true
    init: true
    entrypoint: ["bash"]
    restart: "no"
    volumes:
      - ./openclaw-data/.openclaw:/home/node/.openclaw

  openclaw-gateway:
    build:
      context: .
      dockerfile: Dockerfile
    environment: *openclaw-env
    init: true
    command: ["openclaw", "gateway", "run", "--bind", "lan", "--port", "__GATEWAY_PORT__"]
    ports:
      - "__GATEWAY_PORT__:__GATEWAY_PORT__"
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
    entrypoint: ["bash"]
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

EXPOSE __GATEWAY_PORT__

CMD ["openclaw", "gateway", "run", "--bind", "lan", "--port", "__GATEWAY_PORT__"]
EOF

write_file "$TARGET_README" <<'EOF'
# README

Document this claw instance here.
EOF

download_file "README.md" "$TARGET_README_CLAW"
download_file "README.claw-onboard.md" "$TARGET_README_ONBOARD"
download_file "README.claw-run.md" "$TARGET_README_RUN"

PORT="$GATEWAY_PORT" perl -0pi -e 's/__GATEWAY_PORT__/$ENV{PORT}/g' "$TARGET_DOCKER_COMPOSE" "$TARGET_DOCKERFILE"
rewrite_port_in_file "$TARGET_README_CLAW"
rewrite_port_in_file "$TARGET_README_ONBOARD"
rewrite_port_in_file "$TARGET_README_RUN"

echo "Created:"
echo "  docker-compose.yml"
echo "  Dockerfile"
echo "  README.md"
echo "  README.claw.md"
echo "  README.claw-onboard.md"
echo "  README.claw-run.md"
echo
echo "Next:"
echo "  To continue with onboarding, read README.claw-onboard.md"
echo "  and run the onboard steps from that file."
