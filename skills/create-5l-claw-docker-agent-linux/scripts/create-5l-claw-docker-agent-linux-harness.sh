#!/usr/bin/env bash
set -euo pipefail

RAW_CLAW_DOCKER_SCRIPT="https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/claw-docker.sh"
DEFAULT_PORT="18789"
MAX_PORT="65535"

agent_dir=""
requested_port=""
openclaw_version=""

usage() {
  cat <<'EOF'
Usage:
  create-5l-claw-docker-agent-linux-harness.sh --agent-dir <path> --openclaw-version <version> [--port <port>]
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

validate_port() {
  local port="$1"

  [[ "$port" =~ ^[0-9]+$ ]] || fail "port must be numeric"
  (( port >= 1 && port <= MAX_PORT )) || fail "port must be between 1 and ${MAX_PORT}"
}

validate_openclaw_version() {
  local version="$1"

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || fail "--openclaw-version must be a valid OpenClaw version"
}

port_listening() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltn | awk '{print $4}' | grep -Eq "(^|:)${port}$"
    return $?
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi

  fail "cannot check port availability: install ss or lsof"
}

select_port() {
  local port

  if [[ -n "$requested_port" ]]; then
    validate_port "$requested_port"
    ! port_listening "$requested_port" || fail "requested port is not available: ${requested_port}"
    printf '%s\n' "$requested_port"
    return 0
  fi

  for (( port = DEFAULT_PORT; port <= MAX_PORT; port++ )); do
    if ! port_listening "$port"; then
      printf '%s\n' "$port"
      return 0
    fi
  done

  fail "no available port found"
}

run_claw_docker_init() {
  local port="$1"
  local selected_openclaw_version="$2"
  local temp_script=""

  (
    cd "$agent_dir"
    temp_script="$(mktemp)"
    trap 'rm -f "$temp_script"' EXIT
    curl -fsSL "${RAW_CLAW_DOCKER_SCRIPT}?skip-cache=$(date +%s)" -o "$temp_script"
    chmod +x "$temp_script"
    bash "$temp_script" init --port "$port" --openclaw-version "$selected_openclaw_version"
  )
}

build_agent_image() {
  (
    cd "$agent_dir"
    docker compose build
  )
}

extract_openclaw_version() {
  grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?' | head -n 1 || true
}

verify_installed_openclaw_version() {
  local expected_version="$1"
  local version_output=""
  local installed_version=""

  (
    cd "$agent_dir"
    version_output="$(docker compose run --rm --no-deps --entrypoint openclaw openclaw-standalone-cli --version)"
    installed_version="$(printf '%s\n' "$version_output" | extract_openclaw_version)"
    [[ -n "$installed_version" ]] || fail "could not determine the installed OpenClaw version"
    [[ "$installed_version" == "$expected_version" ]] || fail "installed OpenClaw version ${installed_version} does not match requested version ${expected_version}"
  )
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-dir)
      [[ $# -ge 2 ]] || fail "--agent-dir requires a value"
      agent_dir="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || fail "--port requires a value"
      requested_port="$2"
      shift 2
      ;;
    --openclaw-version)
      [[ $# -ge 2 ]] || fail "--openclaw-version requires a value"
      openclaw_version="$2"
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
[[ ! -e "$agent_dir" ]] || fail "agent directory already exists: ${agent_dir}"
[[ -n "$openclaw_version" ]] || fail "--openclaw-version is required"
validate_openclaw_version "$openclaw_version"

require_command curl
require_command docker
docker compose version >/dev/null 2>&1 || fail "Docker Compose is not available as 'docker compose'"

gateway_port="$(select_port)"

mkdir -p "$(dirname "$agent_dir")"
mkdir "$agent_dir"

run_claw_docker_init "$gateway_port" "$openclaw_version"
build_agent_image
verify_installed_openclaw_version "$openclaw_version"

cat <<EOF
OpenClaw Docker harness created.
  folder: ${agent_dir}
  gateway_port: ${gateway_port}
  openclaw_version: ${openclaw_version}
EOF
