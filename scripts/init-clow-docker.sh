#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash ./scripts/init-clow-docker.sh
#   bash ./scripts/init-clow-docker.sh --port 19001
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/init-clow-docker.sh?skip-cache=$(date +%s)" | bash
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/init-clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- --port 19001

ROOT_DIR="${PWD}"
RAW_BASE_URL="https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main"
COMMON_HELPER_PATH="scripts/clow-docker-common.sh"
COMMON_HELPER_NAME="clow-docker-common.sh"
TMP_COMMON_HELPER=""
GATEWAY_PORT=""
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
Usage: scripts/init-clow-docker.sh [--port <port>]
EOF
}

trap cleanup_common_helper EXIT
load_common_helper

GATEWAY_PORT="$DEFAULT_GATEWAY_PORT"

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
assert_directory_empty "$ROOT_DIR"

mkdir -p "${ROOT_DIR}/.openclaw" "${ROOT_DIR}/.secrets/git/.ssh" "${ROOT_DIR}/.secrets/gogcli/.config"

create_placeholder_readme "${ROOT_DIR}/README.md"
sync_managed_downloads "$ROOT_DIR"
mark_managed_executables "$ROOT_DIR"
rewrite_port_in_targets "$ROOT_DIR" "$GATEWAY_PORT"

echo "Created:"
echo "  README.md"
echo "  .gitignore"
echo "  docker-compose.yml"
echo "  Dockerfile"
echo "  README.claw.md"
echo "  README.claw-onboard.md"
echo "  README.claw-run.md"
echo "  README.gmail.md"
echo "  scripts/init-clow-docker.sh"
echo "  scripts/update-clow-docker.sh"
echo "  scripts/clow-docker-common.sh"
echo "  .openclaw/.gitignore"
echo "  .openclaw/complete-onboard.sh"
echo "  .secrets/git/.ssh/"
echo "  .secrets/gogcli/.config/"
echo "  journey-to-seed.sh"
echo
echo "Next:"
echo "  To continue with onboarding, read README.claw-onboard.md"
echo "  and run the onboard steps from that file."
