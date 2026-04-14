#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash ./scripts/clow-docker.sh init
#   bash ./scripts/clow-docker.sh init --port 19001
#   bash ./scripts/clow-docker.sh update
#   bash ./scripts/clow-docker.sh update --port 19001
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- init
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- init --port 19001
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- update
#   curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- update --port 19001

ROOT_DIR="${PWD}"
RAW_BASE_URL="${CLAW_DOCKER_RAW_BASE_URL:-https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main}"
SELF_PATH_RELATIVE="scripts/clow-docker.sh"
SELF_REFRESH_ENV_VAR="CLAW_DOCKER_SKIP_SELF_REFRESH"
DEFAULT_GATEWAY_PORT="18789"
TMP_SELF_SCRIPT=""
SCRIPT_DIR=""
SCRIPT_SOURCE_PATH=""

MANAGED_DOWNLOAD_SPECS=(
  ".openclaw/.secrets/.env.example:.openclaw/.secrets/.env.example"
  "project-root.gitignore:.gitignore"
  "docker-compose.yml:docker-compose.yml"
  "Dockerfile:Dockerfile"
  "docs/README.claw.md:docs/README.claw.md"
  "docs/README.onboard.md:docs/README.onboard.md"
  "docs/README.run.md:docs/README.run.md"
  "docs/README.google.md:docs/README.google.md"
  ".openclaw/.gitignore:.openclaw/.gitignore"
  ".openclaw/_scripts/complete-onboard.sh:.openclaw/_scripts/complete-onboard.sh"
  ".openclaw/skills/backup-to-git/SKILL.md:.openclaw/skills/backup-to-git/SKILL.md"
  ".openclaw/skills/backup-to-git/scripts/backup-state-to-git.sh:.openclaw/skills/backup-to-git/scripts/backup-state-to-git.sh"
  "scripts/journey-to-seed.sh:scripts/journey-to-seed.sh"
  "scripts/clow-docker.sh:scripts/clow-docker.sh"
)

EXECUTABLE_MANAGED_FILES=(
  ".openclaw/_scripts/complete-onboard.sh"
  ".openclaw/skills/backup-to-git/scripts/backup-state-to-git.sh"
  "scripts/journey-to-seed.sh"
  "scripts/clow-docker.sh"
)

PORT_REWRITE_TARGETS=(
  "docker-compose.yml"
  "Dockerfile"
  "docs/README.claw.md"
  "docs/README.onboard.md"
  "docs/README.run.md"
  ".openclaw/_scripts/complete-onboard.sh"
)

if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  SCRIPT_SOURCE_PATH="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"
fi

cleanup_temp_files() {
  if [[ -n "${TMP_SELF_SCRIPT:-}" && -f "${TMP_SELF_SCRIPT}" ]]; then
    rm -f "${TMP_SELF_SCRIPT}"
  fi
}

usage() {
  cat <<'EOF'
Usage:
  scripts/clow-docker.sh init [--port <port>]
  scripts/clow-docker.sh update [--port <port>]
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

path_in_list() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

download_file_atomic() {
  local remote_name="$1"
  local target_path="$2"
  local target_dir target_name temp_path

  target_dir="$(dirname "$target_path")"
  target_name="$(basename "$target_path")"

  mkdir -p "$target_dir"
  temp_path="$(mktemp "${target_dir}/.${target_name}.tmp.XXXXXX")"

  if ! curl -fsSL "${RAW_BASE_URL}/${remote_name}" -o "$temp_path"; then
    rm -f "$temp_path"
    return 1
  fi

  mv "$temp_path" "$target_path"
}

sync_managed_downloads() {
  local root_dir="$1"
  shift
  local preserve_existing=()
  local spec remote_name target_relative target_path

  if [[ $# -gt 0 ]]; then
    preserve_existing=("$@")
  fi

  for spec in "${MANAGED_DOWNLOAD_SPECS[@]}"; do
    remote_name="${spec%%:*}"
    target_relative="${spec#*:}"
    target_path="${root_dir}/${target_relative}"

    if path_in_list "$target_relative" "${preserve_existing[@]-}" && [[ -e "$target_path" ]]; then
      continue
    fi

    download_file_atomic "$remote_name" "$target_path"
  done
}

mark_managed_executables() {
  local root_dir="$1"
  local relative_path

  for relative_path in "${EXECUTABLE_MANAGED_FILES[@]}"; do
    if [[ -f "${root_dir}/${relative_path}" ]]; then
      chmod +x "${root_dir}/${relative_path}"
    fi
  done
}

create_placeholder_readme() {
  local path="$1"

  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
# README

Document this claw instance here.
EOF
}

rewrite_port_in_file() {
  local path="$1"
  local port="$2"

  if [[ -f "$path" ]]; then
    PORT="$port" perl -0pi -e 's/18789/$ENV{PORT}/g' "$path"
  fi
}

rewrite_port_in_targets() {
  local root_dir="$1"
  local port="$2"
  local relative_path

  for relative_path in "${PORT_REWRITE_TARGETS[@]}"; do
    rewrite_port_in_file "${root_dir}/${relative_path}" "$port"
  done
}

detect_existing_port() {
  local root_dir="$1"
  local docker_compose_path="$root_dir/docker-compose.yml"
  local onboard_script_path="$root_dir/.openclaw/_scripts/complete-onboard.sh"
  local port=""

  if [[ -f "$docker_compose_path" ]]; then
    port="$(sed -n 's/^[[:space:]]*-[[:space:]]*"\([0-9][0-9]*\):[0-9][0-9]*".*/\1/p' "$docker_compose_path" | head -n 1)"
  fi

  if [[ -z "$port" && -f "$onboard_script_path" ]]; then
    port="$(sed -n 's/^GATEWAY_PORT="\([0-9][0-9]*\)"/\1/p' "$onboard_script_path" | head -n 1)"
  fi

  if [[ -n "$port" ]]; then
    printf '%s\n' "$port"
    return 0
  fi

  return 1
}

assert_directory_empty() {
  local root_dir="$1"
  local first_entry

  first_entry="$(find "$root_dir" -mindepth 1 -maxdepth 1 -print -quit)"
  if [[ -n "$first_entry" ]]; then
    echo "Error: target directory is not empty: ${root_dir}. Use scripts/clow-docker.sh update for existing projects." >&2
    exit 1
  fi
}

remove_legacy_bootstrap_files() {
  local root_dir="$1"
  local legacy_relative

  for legacy_relative in \
    "journey-to-seed.sh" \
    "clow-docker-common.sh" \
    "init-clow-docker.sh" \
    "update-clow-docker.sh" \
    "README.claw.md" \
    "README.claw-onboard.md" \
    "README.claw-run.md" \
    "README.gmail.md" \
    "docs/README.claw-onboard.md" \
    "docs/README.claw-run.md" \
    "docs/README.gmail.md" \
    ".openclaw/complete-onboard.sh" \
    "scripts/clow-docker-common.sh" \
    "scripts/init-clow-docker.sh" \
    "scripts/update-clow-docker.sh" \
    ".openclaw/_scripts/clow-docker.sh" \
    ".openclaw/_scripts/journey-to-seed.sh"
  do
    if [[ -e "${root_dir}/${legacy_relative}" ]]; then
      rm -f "${root_dir}/${legacy_relative}"
    fi
  done
}

migrate_legacy_secrets_dir() {
  local legacy_dir="${ROOT_DIR}/.secrets"
  local target_dir="${ROOT_DIR}/.openclaw/.secrets"
  local path name

  if [[ ! -d "$legacy_dir" ]]; then
    return
  fi

  if [[ ! -e "$target_dir" ]]; then
    mv "$legacy_dir" "$target_dir"
    return
  fi

  mkdir -p "$target_dir"

  for path in "$legacy_dir"/.[!.]* "$legacy_dir"/..?* "$legacy_dir"/*; do
    if [[ ! -e "$path" ]]; then
      continue
    fi

    name="$(basename "$path")"
    if [[ -e "${target_dir}/${name}" ]]; then
      continue
    fi

    mv "$path" "${target_dir}/${name}"
  done

  rmdir "$legacy_dir" 2>/dev/null || true
}

refresh_self_for_update() {
  if [[ "${!SELF_REFRESH_ENV_VAR:-0}" == "1" ]]; then
    return
  fi

  if [[ -z "$SCRIPT_SOURCE_PATH" ]]; then
    return
  fi

  TMP_SELF_SCRIPT="$(mktemp)"

  if ! curl -fsSL "${RAW_BASE_URL}/${SELF_PATH_RELATIVE}" -o "${TMP_SELF_SCRIPT}"; then
    echo "Error: failed to download the latest scripts/clow-docker.sh for update." >&2
    exit 1
  fi

  chmod +x "${TMP_SELF_SCRIPT}"
  env "${SELF_REFRESH_ENV_VAR}=1" CLAW_DOCKER_RAW_BASE_URL="${RAW_BASE_URL}" bash "${TMP_SELF_SCRIPT}" "$@"
  exit $?
}

run_init() {
  local gateway_port="$1"

  validate_port "$gateway_port"
  assert_directory_empty "$ROOT_DIR"

  mkdir -p \
    "${ROOT_DIR}/.openclaw" \
    "${ROOT_DIR}/.openclaw/.secrets/git/.ssh" \
    "${ROOT_DIR}/.openclaw/.secrets/gogcli/.config"

  create_placeholder_readme "${ROOT_DIR}/README.md"
  sync_managed_downloads "$ROOT_DIR"
  mark_managed_executables "$ROOT_DIR"
  rewrite_port_in_targets "$ROOT_DIR" "$gateway_port"
  remove_legacy_bootstrap_files "$ROOT_DIR"

  echo "Created:"
  echo "  README.md"
  echo "  .openclaw/.secrets/.env.example"
  echo "  .gitignore"
  echo "  docker-compose.yml"
  echo "  Dockerfile"
  echo "  docs/README.claw.md"
  echo "  docs/README.onboard.md"
  echo "  docs/README.run.md"
  echo "  docs/README.google.md"
  echo "  .openclaw/skills/backup-to-git/"
  echo "  scripts/clow-docker.sh"
  echo "  scripts/journey-to-seed.sh"
  echo "  .openclaw/.gitignore"
  echo "  .openclaw/_scripts/complete-onboard.sh"
  echo "  .openclaw/.secrets/git/.ssh/"
  echo "  .openclaw/.secrets/gogcli/.config/"
  echo
  echo "Next:"
  echo "  To continue with onboarding, read docs/README.onboard.md"
  echo "  and run the onboard steps from that file."
}

run_update() {
  local requested_port="$1"
  local readme_already_exists="0"
  local openclaw_gitignore_already_exists="0"
  local gateway_port="$requested_port"

  if [[ ${#UPDATE_ARGS[@]} -gt 0 ]]; then
    refresh_self_for_update update "${UPDATE_ARGS[@]}"
  else
    refresh_self_for_update update
  fi

  if [[ -z "$gateway_port" ]]; then
    if ! gateway_port="$(detect_existing_port "$ROOT_DIR")"; then
      echo "Error: could not detect the existing gateway port. Use --port <port>." >&2
      exit 1
    fi
  fi

  validate_port "$gateway_port"

  mkdir -p "${ROOT_DIR}/.openclaw"
  migrate_legacy_secrets_dir

  if [[ -e "${ROOT_DIR}/README.md" ]]; then
    readme_already_exists="1"
  fi

  if [[ -e "${ROOT_DIR}/.openclaw/.gitignore" ]]; then
    openclaw_gitignore_already_exists="1"
  fi

  if [[ ! -e "${ROOT_DIR}/README.md" ]]; then
    create_placeholder_readme "${ROOT_DIR}/README.md"
  fi

  sync_managed_downloads "$ROOT_DIR" ".openclaw/.gitignore"
  mark_managed_executables "$ROOT_DIR"
  rewrite_port_in_targets "$ROOT_DIR" "$gateway_port"
  remove_legacy_bootstrap_files "$ROOT_DIR"

  echo "Updated:"
  echo "  docker-compose.yml"
  echo "  Dockerfile"
  echo "  .gitignore"
  echo "  .openclaw/.secrets/.env.example"
  echo "  .openclaw/_scripts/complete-onboard.sh"
  echo "  .openclaw/skills/backup-to-git/"
  echo "  docs/README.claw.md"
  echo "  docs/README.onboard.md"
  echo "  docs/README.run.md"
  echo "  docs/README.google.md"
  echo "  scripts/clow-docker.sh"
  echo "  scripts/journey-to-seed.sh"
  if [[ "$readme_already_exists" == "1" || "$openclaw_gitignore_already_exists" == "1" ]]; then
    echo
    echo "Kept:"
  fi
  if [[ "$readme_already_exists" == "1" ]]; then
    echo "  README.md"
  fi
  if [[ "$openclaw_gitignore_already_exists" == "1" ]]; then
    echo "  .openclaw/.gitignore"
  fi
}

trap cleanup_temp_files EXIT

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  init|update)
    ;;
  help|-h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown command: ${COMMAND}" >&2
    usage >&2
    exit 1
    ;;
esac

PORT_ARG=""
UPDATE_ARGS=()

if [[ $# -gt 0 ]]; then
  UPDATE_ARGS=("$@")
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      if [[ $# -lt 2 ]]; then
        echo "Error: --port requires a value" >&2
        usage >&2
        exit 1
      fi
      PORT_ARG="$2"
      shift 2
      ;;
    --port=*)
      PORT_ARG="${1#*=}"
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

case "$COMMAND" in
  init)
    if [[ -z "$PORT_ARG" ]]; then
      PORT_ARG="$DEFAULT_GATEWAY_PORT"
    fi
    run_init "$PORT_ARG"
    ;;
  update)
    run_update "$PORT_ARG"
    ;;
esac
