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
  ".openclaw/_secrets/.env.example:.openclaw/_secrets/.env.example"
  "docker-compose.yml:docker-compose.yml"
  "Dockerfile:Dockerfile"
  "README.md:docs/README.md"
  "docs/README.backup.md:docs/README.backup.md"
  "docs/README.onboard.md:docs/README.onboard.md"
  "docs/README.run.md:docs/README.run.md"
  "docs/README.google.md:docs/README.google.md"
  "docs/README.telegram.md:docs/README.telegram.md"
  ".openclaw/workspace.gitignore:.openclaw/.gitignore"
  ".openclaw/_scripts/complete-onboard.sh:.openclaw/_scripts/complete-onboard.sh"
  ".openclaw/_scripts/initialize-workspace.sh:.openclaw/_scripts/initialize-workspace.sh"
  ".openclaw/_scripts/restore-state.sh:.openclaw/_scripts/restore-state.sh"
  ".openclaw/skills/backup-workspace-to-git/SKILL.md:.openclaw/skills/backup-workspace-to-git/SKILL.md"
  ".openclaw/skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh:.openclaw/skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh"
  ".openclaw/skills/backup-state-to-drive/SKILL.md:.openclaw/skills/backup-state-to-drive/SKILL.md"
  ".openclaw/skills/backup-state-to-drive/state.include:.openclaw/skills/backup-state-to-drive/state.include"
  ".openclaw/skills/backup-state-to-drive/scripts/backup-state-to-drive.sh:.openclaw/skills/backup-state-to-drive/scripts/backup-state-to-drive.sh"
  "scripts/commit-push-workspace-from-host.sh:scripts/commit-push-workspace-from-host.sh"
  "scripts/journey-to-seed.sh:scripts/journey-to-seed.sh"
  "scripts/clow-docker.sh:scripts/clow-docker.sh"
)

EXECUTABLE_MANAGED_FILES=(
  ".openclaw/_scripts/complete-onboard.sh"
  ".openclaw/_scripts/initialize-workspace.sh"
  ".openclaw/_scripts/restore-state.sh"
  ".openclaw/skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh"
  ".openclaw/skills/backup-state-to-drive/scripts/backup-state-to-drive.sh"
  "scripts/commit-push-workspace-from-host.sh"
  "scripts/journey-to-seed.sh"
  "scripts/clow-docker.sh"
)

MANAGED_OUTPUT_PATHS=(
  ".openclaw/_scripts/complete-onboard.sh"
  ".openclaw/_scripts/initialize-workspace.sh"
  ".openclaw/_scripts/restore-state.sh"
  ".openclaw/_secrets/.env.example"
  ".openclaw/skills/backup-state-to-drive/"
  ".openclaw/skills/backup-workspace-to-git/"
  "Dockerfile"
  "docker-compose.yml"
  "docs/README.backup.md"
  "docs/README.google.md"
  "docs/README.md"
  "docs/README.onboard.md"
  "docs/README.run.md"
  "docs/README.telegram.md"
  "scripts/clow-docker.sh"
  "scripts/commit-push-workspace-from-host.sh"
  "scripts/journey-to-seed.sh"
)

INIT_ONLY_OUTPUT_PATHS=(
  ".openclaw/.gitignore"
  ".openclaw/_secrets/git/.ssh/"
  ".openclaw/_secrets/gogcli/.config/"
  "README.md"
)

PORT_REWRITE_TARGETS=(
  "docker-compose.yml"
  "Dockerfile"
  "docs/README.md"
  "docs/README.backup.md"
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

rewrite_project_name_in_file() {
  local path="$1"
  local project_name="$2"

  if [[ -f "$path" ]]; then
    PROJECT_NAME="$project_name" perl -0pi -e 's/__PROJECT_NAME__/$ENV{PROJECT_NAME}/g' "$path"
  fi
}

rewrite_project_name_in_targets() {
  local root_dir="$1"
  local project_name="$2"

  rewrite_project_name_in_file \
    "${root_dir}/.openclaw/skills/backup-state-to-drive/scripts/backup-state-to-drive.sh" \
    "$project_name"
}

rewrite_docs_readme_links() {
  local root_dir="$1"
  local docs_readme_path="${root_dir}/docs/README.md"

  if [[ -f "$docs_readme_path" ]]; then
    perl -0pi -e 's{\(docs/(README[^)]+)\)}{(./$1)}g' "$docs_readme_path"
  fi
}

print_output_paths() {
  local heading="$1"
  shift
  local relative_path

  echo "${heading}:"
  for relative_path in "$@"; do
    echo "  ${relative_path}"
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
  local project_name

  project_name="$(basename "$ROOT_DIR")"

  validate_port "$gateway_port"
  assert_directory_empty "$ROOT_DIR"

  mkdir -p \
    "${ROOT_DIR}/.openclaw" \
    "${ROOT_DIR}/.openclaw/_secrets/git/.ssh" \
    "${ROOT_DIR}/.openclaw/_secrets/gogcli/.config"

  create_placeholder_readme "${ROOT_DIR}/README.md"
  sync_managed_downloads "$ROOT_DIR"
  mark_managed_executables "$ROOT_DIR"
  rewrite_port_in_targets "$ROOT_DIR" "$gateway_port"
  rewrite_project_name_in_targets "$ROOT_DIR" "$project_name"
  rewrite_docs_readme_links "$ROOT_DIR"

  print_output_paths "Created" "${INIT_ONLY_OUTPUT_PATHS[@]}" "${MANAGED_OUTPUT_PATHS[@]}"
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
  local project_name

  project_name="$(basename "$ROOT_DIR")"

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
  rewrite_project_name_in_targets "$ROOT_DIR" "$project_name"
  rewrite_docs_readme_links "$ROOT_DIR"

  print_output_paths "Updated" "${MANAGED_OUTPUT_PATHS[@]}"
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
