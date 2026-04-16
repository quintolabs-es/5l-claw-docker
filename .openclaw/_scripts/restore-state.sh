#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   /home/node/.openclaw/_scripts/restore-state.sh <path-to-restored-.openclaw>

TARGET_DIR="/home/node/.openclaw"

usage() {
  cat <<'EOF'
Usage: restore-state.sh <path-to-restored-.openclaw>
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

shopt -s nullglob dotglob
SOURCE_ENTRIES=("${SOURCE_DIR}"/*)
shopt -u nullglob dotglob

if [[ ${#SOURCE_ENTRIES[@]} -eq 0 ]]; then
  echo "Error: source directory is empty: ${SOURCE_DIR}" >&2
  exit 1
fi

for source_path in "${SOURCE_ENTRIES[@]}"; do
  name="$(basename "$source_path")"
  target_path="${TARGET_DIR}/${name}"

  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
  echo "Restored state: ${name}"
done
