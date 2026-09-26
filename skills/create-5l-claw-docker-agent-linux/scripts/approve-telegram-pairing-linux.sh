#!/usr/bin/env bash
set -euo pipefail

agent_dir=""
pairing_code=""

usage() {
  cat <<'EOF'
Usage:
  approve-telegram-pairing-linux.sh --agent-dir <path> --pairing-code <code>

Approves a Telegram pairing code for an existing Meta Garra OpenClaw agent.
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
    --pairing-code)
      [[ $# -ge 2 ]] || fail "--pairing-code requires a value"
      pairing_code="$2"
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
[[ -n "$pairing_code" ]] || fail "--pairing-code is required"
[[ -d "$agent_dir" ]] || fail "agent directory not found: ${agent_dir}"
[[ -f "${agent_dir}/docker-compose.yml" ]] || fail "docker-compose.yml not found in agent directory: ${agent_dir}"

(
  cd "$agent_dir"
  docker compose run --rm --entrypoint openclaw openclaw-gateway-cli \
    pairing approve telegram "$pairing_code"
)
