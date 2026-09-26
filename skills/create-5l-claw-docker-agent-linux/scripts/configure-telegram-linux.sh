#!/usr/bin/env bash
set -euo pipefail

agent_dir=""
bot_token=""

usage() {
  cat <<'EOF'
Usage:
  configure-telegram-linux.sh --agent-dir <path> --bot-token <token>

Configures Telegram for an existing Meta Garra OpenClaw agent.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-dir)
      [[ $# -ge 2 ]] || fail "--agent-dir requires a value"
      agent_dir="$2"
      shift 2
      ;;
    --bot-token)
      [[ $# -ge 2 ]] || fail "--bot-token requires a value"
      bot_token="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$agent_dir" ]] || fail "--agent-dir is required"
[[ -n "$bot_token" ]] || fail "--bot-token is required"
[[ -d "$agent_dir" ]] || fail "agent directory not found: ${agent_dir}"
[[ -f "${agent_dir}/docker-compose.yml" ]] || fail "docker-compose.yml not found in agent directory: ${agent_dir}"

(
  cd "$agent_dir"
  docker compose run --rm --entrypoint openclaw openclaw-gateway-cli \
    channels add --channel telegram --token "$bot_token"
  docker compose run --rm --entrypoint openclaw openclaw-gateway-cli \
    channels status --probe
  docker compose run --rm --entrypoint openclaw openclaw-gateway-cli \
    config set channels.telegram.streaming.mode off
)
