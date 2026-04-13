#!/usr/bin/env bash

DEFAULT_GATEWAY_PORT="18789"

MANAGED_DOWNLOAD_SPECS=(
  "project-root.gitignore:.gitignore"
  "docker-compose.yml:docker-compose.yml"
  "Dockerfile:Dockerfile"
  "README.md:README.claw.md"
  "README.claw-onboard.md:README.claw-onboard.md"
  "README.claw-run.md:README.claw-run.md"
  ".openclaw/.gitignore:.openclaw/.gitignore"
  ".openclaw/complete-onboard.sh:.openclaw/complete-onboard.sh"
  "journey-to-seed.sh:journey-to-seed.sh"
  "update-clow-docker.sh:update-clow-docker.sh"
  "clow-docker-common.sh:clow-docker-common.sh"
)

EXECUTABLE_MANAGED_FILES=(
  ".openclaw/complete-onboard.sh"
  "journey-to-seed.sh"
  "update-clow-docker.sh"
)

PORT_REWRITE_TARGETS=(
  "docker-compose.yml"
  "Dockerfile"
  "README.claw.md"
  "README.claw-onboard.md"
  "README.claw-run.md"
  ".openclaw/complete-onboard.sh"
)

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
  local preserve_existing=("$@")
  local spec remote_name target_relative target_path

  for spec in "${MANAGED_DOWNLOAD_SPECS[@]}"; do
    remote_name="${spec%%:*}"
    target_relative="${spec#*:}"
    target_path="${root_dir}/${target_relative}"

    if path_in_list "$target_relative" "${preserve_existing[@]}" && [[ -e "$target_path" ]]; then
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
  local onboard_script_path="$root_dir/.openclaw/complete-onboard.sh"
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
    echo "Error: target directory is not empty: ${root_dir}. Use update-clow-docker.sh for existing projects." >&2
    exit 1
  fi
}
