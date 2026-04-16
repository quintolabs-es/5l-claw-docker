#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   /home/node/.openclaw/_scripts/initialize-workspace.sh <path-to-restored-.openclaw>

TARGET_DIR="/home/node/.openclaw"

usage() {
  cat <<'EOF'
Usage: initialize-workspace.sh <path-to-restored-.openclaw>
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

SOURCE_DIR="$1"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: source directory does not exist: ${SOURCE_DIR}" >&2
  exit 1
fi

initialized_any="0"

if [[ -d "${SOURCE_DIR}/workspace" ]]; then
  rm -rf "${TARGET_DIR}/workspace"
  cp -R "${SOURCE_DIR}/workspace" "${TARGET_DIR}/workspace"
  echo "Initialized workspace: workspace"
  initialized_any="1"
fi

if [[ -e "${SOURCE_DIR}/.gitignore" ]]; then
  rm -rf "${TARGET_DIR}/.gitignore"
  cp -R "${SOURCE_DIR}/.gitignore" "${TARGET_DIR}/.gitignore"
  echo "Initialized workspace: .gitignore"
  initialized_any="1"
fi

if [[ "$initialized_any" != "1" ]]; then
  echo "Error: source does not contain workspace/ or .gitignore: ${SOURCE_DIR}" >&2
  exit 1
fi
