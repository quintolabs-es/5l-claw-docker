#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${PWD}"
RAW_BASE_URL="https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main"
GATEWAY_PORT="18789"
DOWNLOAD_FILE_SPECS=(
  ".gitignore:.gitignore"
  "docker-compose.yml:docker-compose.yml"
  "Dockerfile:Dockerfile"
  "README.md:README.claw.md"
  "README.claw-onboard.md:README.claw-onboard.md"
  "README.claw-run.md:README.claw-run.md"
  "journey-to-seed.sh:journey-to-seed.sh"
)
EXECUTABLE_DOWNLOADED_FILES=(
  "journey-to-seed.sh"
)

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

assert_download_targets_missing() {
  local spec target_relative

  for spec in "${DOWNLOAD_FILE_SPECS[@]}"; do
    target_relative="${spec#*:}"
    assert_missing "${ROOT_DIR}/${target_relative}"
  done
}

download_manifest_files() {
  local spec remote_name target_relative

  for spec in "${DOWNLOAD_FILE_SPECS[@]}"; do
    remote_name="${spec%%:*}"
    target_relative="${spec#*:}"
    download_file "$remote_name" "${ROOT_DIR}/${target_relative}"
  done
}

mark_downloaded_executables() {
  local relative_path

  for relative_path in "${EXECUTABLE_DOWNLOADED_FILES[@]}"; do
    chmod +x "${ROOT_DIR}/${relative_path}"
  done
}

rewrite_port_in_file() {
  local path="$1"
  PORT="$GATEWAY_PORT" perl -0pi -e 's/18789/$ENV{PORT}/g' "$path"
}

ensure_onboard_gateway_port_step() {
  local path="$1"
  perl -0pi -e '
    my $anchor = "openclaw config set gateway.bind lan\n";
    my $step = "openclaw config set gateway.port 18789 --strict-json\n";

    if (index($_, $step) < 0) {
      s/\Q$anchor\E/$anchor$step/
        or die "Failed to insert gateway.port onboarding step into $ARGV\n";
    }
  ' "$path"
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

assert_missing "$TARGET_README"
assert_download_targets_missing

write_file "$TARGET_README" <<'EOF'
# README

Document this claw instance here.
EOF

download_manifest_files
mark_downloaded_executables

ensure_onboard_gateway_port_step "$TARGET_README_ONBOARD"

rewrite_port_in_file "$TARGET_DOCKER_COMPOSE"
rewrite_port_in_file "$TARGET_DOCKERFILE"
rewrite_port_in_file "$TARGET_README_CLAW"
rewrite_port_in_file "$TARGET_README_ONBOARD"
rewrite_port_in_file "$TARGET_README_RUN"

echo "Created:"
echo "  docker-compose.yml"
echo "  Dockerfile"
echo "  .gitignore"
echo "  README.md"
echo "  README.claw.md"
echo "  README.claw-onboard.md"
echo "  README.claw-run.md"
echo "  journey-to-seed.sh"
echo
echo "Next:"
echo "  To continue with onboarding, read README.claw-onboard.md"
echo "  and run the onboard steps from that file."
