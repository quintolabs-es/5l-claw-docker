#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash ./scripts/update-clow-docker.sh
#   bash ./scripts/update-clow-docker.sh --port 19001
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/update-clow-docker.sh?skip-cache=$(date +%s)" | bash

ROOT_DIR="${PWD}"
RAW_BASE_URL="https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main"
COMMON_HELPER_PATH="scripts/clow-docker-common.sh"
COMMON_HELPER_NAME="clow-docker-common.sh"
TMP_COMMON_HELPER=""
GATEWAY_PORT=""
README_ALREADY_EXISTS="0"
OPENCLAW_GITIGNORE_ALREADY_EXISTS="0"
SCRIPT_DIR=""

if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

cleanup_common_helper() {
  if [[ -n "${TMP_COMMON_HELPER:-}" && -f "${TMP_COMMON_HELPER}" ]]; then
    rm -f "${TMP_COMMON_HELPER}"
  fi
}

load_common_helper() {
  local local_helper=""

  if [[ -n "$SCRIPT_DIR" && -f "${SCRIPT_DIR}/${COMMON_HELPER_NAME}" ]]; then
    local_helper="${SCRIPT_DIR}/${COMMON_HELPER_NAME}"
  elif [[ -f "${ROOT_DIR}/${COMMON_HELPER_PATH}" ]]; then
    local_helper="${ROOT_DIR}/${COMMON_HELPER_PATH}"
  fi

  if [[ -n "$local_helper" ]]; then
    # shellcheck source=/dev/null
    . "$local_helper"
    return
  fi

  TMP_COMMON_HELPER="$(mktemp)"
  curl -fsSL "${RAW_BASE_URL}/${COMMON_HELPER_PATH}" -o "${TMP_COMMON_HELPER}"
  # shellcheck source=/dev/null
  . "${TMP_COMMON_HELPER}"
}

usage() {
  cat <<'EOF'
Usage: update-clow-docker.sh [--port <port>]
EOF
}

trap cleanup_common_helper EXIT
load_common_helper

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

if [[ -z "$GATEWAY_PORT" ]]; then
  if ! GATEWAY_PORT="$(detect_existing_port "$ROOT_DIR")"; then
    echo "Error: could not detect the existing gateway port. Use --port <port>." >&2
    exit 1
  fi
fi

validate_port "$GATEWAY_PORT"

mkdir -p "${ROOT_DIR}/.openclaw"

if [[ -e "${ROOT_DIR}/README.md" ]]; then
  README_ALREADY_EXISTS="1"
fi

if [[ -e "${ROOT_DIR}/.openclaw/.gitignore" ]]; then
  OPENCLAW_GITIGNORE_ALREADY_EXISTS="1"
fi

if [[ ! -e "${ROOT_DIR}/README.md" ]]; then
  create_placeholder_readme "${ROOT_DIR}/README.md"
fi

sync_managed_downloads "$ROOT_DIR" ".openclaw/.gitignore"
mark_managed_executables "$ROOT_DIR"
rewrite_port_in_targets "$ROOT_DIR" "$GATEWAY_PORT"

echo "Updated:"
echo "  docker-compose.yml"
echo "  Dockerfile"
echo "  .gitignore"
echo "  README.claw.md"
echo "  README.claw-onboard.md"
echo "  README.claw-run.md"
echo "  README.gmail.md"
echo "  scripts/update-clow-docker.sh"
echo "  scripts/clow-docker-common.sh"
echo "  .openclaw/complete-onboard.sh"
echo "  journey-to-seed.sh"
if [[ "$README_ALREADY_EXISTS" == "1" || "$OPENCLAW_GITIGNORE_ALREADY_EXISTS" == "1" ]]; then
  echo
  echo "Kept:"
fi
if [[ "$README_ALREADY_EXISTS" == "1" ]]; then
  echo "  README.md"
fi
if [[ "$OPENCLAW_GITIGNORE_ALREADY_EXISTS" == "1" ]]; then
  echo "  .openclaw/.gitignore"
fi
