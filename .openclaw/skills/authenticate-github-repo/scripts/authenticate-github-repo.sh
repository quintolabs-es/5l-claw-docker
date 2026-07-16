#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash skills/authenticate-github-repo/scripts/authenticate-github-repo.sh prepare --github-repo-url <https://github.com/owner/repo> [--replace-auth]
#   bash skills/authenticate-github-repo/scripts/authenticate-github-repo.sh finalize --github-repo-url <https://github.com/owner/repo> [--replace-clone]

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)"
STATE_DIR="${OPENCLAW_DIR}"
WORKSPACE_DIR="${STATE_DIR}/workspace"
REPOS_DIR="${WORKSPACE_DIR}/repos"
SSH_DIR="${HOME}/.ssh"
SSH_CONFIG_PATH="${SSH_DIR}/config"
SSH_KNOWN_HOSTS_PATH="${SSH_DIR}/known_hosts"
AUTH_METADATA_DIR="${STATE_DIR}/_secrets/git/repos"
GITHUB_SSH_HOST_PREFIX="github.com-openclaw"
MODE=""
GITHUB_REPO_URL=""
REPLACE_AUTH="0"
REPLACE_CLONE="0"

usage() {
  cat <<'EOF'
Usage:
  authenticate-github-repo.sh prepare --github-repo-url <https://github.com/owner/repo> [--replace-auth]
  authenticate-github-repo.sh finalize --github-repo-url <https://github.com/owner/repo> [--replace-clone]
EOF
}

normalize_github_repo_url() {
  local repo_url="$1"
  local normalized=""

  normalized="${repo_url%.git}"
  normalized="${normalized%/}"

  if [[ ! "$normalized" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
    echo "Error: GitHub repo URL must be in the form https://github.com/<owner>/<repo>" >&2
    exit 1
  fi

  printf '%s\n' "$normalized"
}

github_repo_name() {
  local normalized_repo_url="$1"
  printf '%s\n' "${normalized_repo_url##*/}"
}

repo_ssh_host_alias() {
  local repo_name="$1"
  printf '%s-%s\n' "$GITHUB_SSH_HOST_PREFIX" "$repo_name"
}

repo_ssh_key_basename() {
  local repo_name="$1"
  printf 'openclaw_github_%s_ed25519\n' "$repo_name"
}

repo_ssh_key_path() {
  local repo_name="$1"
  printf '%s/%s\n' "$SSH_DIR" "$(repo_ssh_key_basename "$repo_name")"
}

repo_metadata_path() {
  local repo_name="$1"
  printf '%s/%s.env\n' "$AUTH_METADATA_DIR" "$repo_name"
}

build_github_ssh_remote() {
  local normalized_repo_url="$1"
  local host_alias="$2"
  local path=""

  path="${normalized_repo_url#https://github.com/}"
  printf 'git@%s:%s.git\n' "$host_alias" "$path"
}

ensure_known_hosts() {
  if [[ ! -f "$SSH_KNOWN_HOSTS_PATH" ]] || ! grep -q '^github\.com ' "$SSH_KNOWN_HOSTS_PATH"; then
    touch "$SSH_KNOWN_HOSTS_PATH"
    ssh-keyscan github.com >> "$SSH_KNOWN_HOSTS_PATH" 2>/dev/null
  fi
}

config_block_start() {
  local repo_name="$1"
  printf '# >>> openclaw github repo %s >>>\n' "$repo_name"
}

config_block_end() {
  local repo_name="$1"
  printf '# <<< openclaw github repo %s <<<\n' "$repo_name"
}

remove_ssh_config_block() {
  local repo_name="$1"
  local start_marker=""
  local end_marker=""
  local temp_path=""

  if [[ ! -f "$SSH_CONFIG_PATH" ]]; then
    return 0
  fi

  start_marker="$(config_block_start "$repo_name")"
  end_marker="$(config_block_end "$repo_name")"
  temp_path="$(mktemp "${SSH_DIR}/.config.tmp.XXXXXX")"

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$SSH_CONFIG_PATH" > "$temp_path"

  mv "$temp_path" "$SSH_CONFIG_PATH"
}

upsert_ssh_config_block() {
  local repo_name="$1"
  local host_alias="$2"
  local ssh_key_path="$3"

  mkdir -p "$SSH_DIR"
  touch "$SSH_CONFIG_PATH"
  chmod 600 "$SSH_CONFIG_PATH"

  remove_ssh_config_block "$repo_name"

  {
    printf '%s\n' "$(config_block_start "$repo_name")"
    cat <<EOF
Host ${host_alias}
  HostName github.com
  User git
  IdentityFile ${ssh_key_path}
  IdentitiesOnly yes
EOF
    printf '%s\n' "$(config_block_end "$repo_name")"
  } >> "$SSH_CONFIG_PATH"
}

test_git_remote_auth() {
  local git_ssh_remote="$1"

  git ls-remote "$git_ssh_remote" >/dev/null 2>&1
}

ensure_ssh_layout() {
  mkdir -p "$SSH_DIR" "$AUTH_METADATA_DIR" "$REPOS_DIR"
  chmod 700 "$SSH_DIR"
  chmod 700 "$AUTH_METADATA_DIR"
  touch "$SSH_KNOWN_HOSTS_PATH"
  chmod 600 "$SSH_KNOWN_HOSTS_PATH"
  ensure_known_hosts
}

print_github_deploy_key_instructions() {
  local public_key_host_path="$1"
  local public_key_value="$2"

  cat <<EOF
GitHub deploy key setup:
  1. Open the target GitHub repository.
  2. Go to Settings.
  3. Go to Deploy keys.
  4. Click Add deploy key.
  5. Paste this public key:
     ${public_key_value}
  6. Enable write access.
  7. Save.

Public key host path:
  ${public_key_host_path}
EOF
}

write_repo_metadata() {
  local repo_name="$1"
  local normalized_repo_url="$2"
  local git_ssh_remote="$3"
  local host_alias="$4"
  local ssh_key_basename="$5"
  local metadata_path=""

  metadata_path="$(repo_metadata_path "$repo_name")"

  cat > "$metadata_path" <<EOF
REPO_NAME=${repo_name}
GITHUB_REPO_URL=${normalized_repo_url}
GIT_SSH_REMOTE=${git_ssh_remote}
SSH_HOST_ALIAS=${host_alias}
SSH_KEY_BASENAME=${ssh_key_basename}
EOF

  chmod 600 "$metadata_path"
}

read_repo_metadata() {
  local repo_name="$1"
  local metadata_path=""

  metadata_path="$(repo_metadata_path "$repo_name")"
  if [[ ! -f "$metadata_path" ]]; then
    return 1
  fi

  # shellcheck disable=SC1090
  source "$metadata_path"
}

remove_repo_auth_material() {
  local repo_name="$1"
  local ssh_key_path=""
  local ssh_pub_key_path=""
  local metadata_path=""

  ssh_key_path="$(repo_ssh_key_path "$repo_name")"
  ssh_pub_key_path="${ssh_key_path}.pub"
  metadata_path="$(repo_metadata_path "$repo_name")"

  rm -f "$ssh_key_path" "$ssh_pub_key_path" "$metadata_path"
  remove_ssh_config_block "$repo_name"
}

repo_clone_path() {
  local repo_name="$1"
  printf '%s/%s\n' "$REPOS_DIR" "$repo_name"
}

ensure_expected_metadata_or_fail() {
  local repo_name="$1"
  local normalized_repo_url="$2"
  local expected_host_alias="$3"
  local expected_key_basename="$4"
  local expected_git_ssh_remote="$5"

  if ! read_repo_metadata "$repo_name"; then
    echo "Error: repo-specific auth material exists for ${repo_name} but no metadata was found. Ask the user whether to replace the old auth setup, then rerun prepare with --replace-auth." >&2
    exit 1
  fi

  if [[ "${GITHUB_REPO_URL}" != "$normalized_repo_url" || "${SSH_HOST_ALIAS}" != "$expected_host_alias" || "${SSH_KEY_BASENAME}" != "$expected_key_basename" || "${GIT_SSH_REMOTE}" != "$expected_git_ssh_remote" ]]; then
    echo "Error: repo name ${repo_name} is already associated with a different GitHub auth setup. Ask the user whether to replace the old auth setup, then rerun prepare with --replace-auth." >&2
    exit 1
  fi
}

prepare_auth() {
  local normalized_repo_url="$1"
  local repo_name=""
  local host_alias=""
  local ssh_key_basename=""
  local ssh_key_path=""
  local ssh_pub_key_path=""
  local git_ssh_remote=""
  local public_key_host_path=""
  local public_key_value=""

  repo_name="$(github_repo_name "$normalized_repo_url")"
  host_alias="$(repo_ssh_host_alias "$repo_name")"
  ssh_key_basename="$(repo_ssh_key_basename "$repo_name")"
  ssh_key_path="$(repo_ssh_key_path "$repo_name")"
  ssh_pub_key_path="${ssh_key_path}.pub"
  git_ssh_remote="$(build_github_ssh_remote "$normalized_repo_url" "$host_alias")"
  public_key_host_path="./.openclaw/_secrets/git/.ssh/${ssh_key_basename}.pub"

  ensure_ssh_layout

  if [[ "$REPLACE_AUTH" == "1" ]]; then
    remove_repo_auth_material "$repo_name"
  fi

  if [[ -f "$ssh_key_path" || -f "$ssh_pub_key_path" || -f "$(repo_metadata_path "$repo_name")" ]]; then
    ensure_expected_metadata_or_fail "$repo_name" "$normalized_repo_url" "$host_alias" "$ssh_key_basename" "$git_ssh_remote"
    upsert_ssh_config_block "$repo_name" "$host_alias" "$ssh_key_path"

    if [[ -f "$ssh_key_path" && -f "$ssh_pub_key_path" ]] && test_git_remote_auth "$git_ssh_remote"; then
      echo "GitHub auth is already active for ${normalized_repo_url}."
      echo "Clone target: workspace/repos/${repo_name}"
      return 0
    fi

    if [[ ! -f "$ssh_pub_key_path" ]]; then
      echo "Error: repo-specific auth metadata exists for ${repo_name}, but the public key file is missing. Ask the user whether to replace the old auth setup, then rerun prepare with --replace-auth." >&2
      exit 1
    fi

    public_key_value="$(cat "$ssh_pub_key_path")"
    print_github_deploy_key_instructions "$public_key_host_path" "$public_key_value"
    echo
    echo "After the deploy key is added in GitHub, rerun finalize for ${normalized_repo_url}."
    return 0
  fi

  ssh-keygen -t ed25519 -N "" -C "${normalized_repo_url}" -f "$ssh_key_path" >/dev/null
  chmod 600 "$ssh_key_path"
  chmod 644 "$ssh_pub_key_path"
  upsert_ssh_config_block "$repo_name" "$host_alias" "$ssh_key_path"
  write_repo_metadata "$repo_name" "$normalized_repo_url" "$git_ssh_remote" "$host_alias" "$ssh_key_basename"

  public_key_value="$(cat "$ssh_pub_key_path")"
  print_github_deploy_key_instructions "$public_key_host_path" "$public_key_value"
  echo
  echo "After the deploy key is added in GitHub, rerun finalize for ${normalized_repo_url}."
}

finalize_auth_and_clone() {
  local normalized_repo_url="$1"
  local repo_name=""
  local host_alias=""
  local ssh_key_basename=""
  local ssh_key_path=""
  local ssh_pub_key_path=""
  local git_ssh_remote=""
  local clone_path=""

  repo_name="$(github_repo_name "$normalized_repo_url")"
  host_alias="$(repo_ssh_host_alias "$repo_name")"
  ssh_key_basename="$(repo_ssh_key_basename "$repo_name")"
  ssh_key_path="$(repo_ssh_key_path "$repo_name")"
  ssh_pub_key_path="${ssh_key_path}.pub"
  git_ssh_remote="$(build_github_ssh_remote "$normalized_repo_url" "$host_alias")"
  clone_path="$(repo_clone_path "$repo_name")"

  ensure_ssh_layout
  ensure_expected_metadata_or_fail "$repo_name" "$normalized_repo_url" "$host_alias" "$ssh_key_basename" "$git_ssh_remote"

  if [[ ! -f "$ssh_key_path" || ! -f "$ssh_pub_key_path" ]]; then
    echo "Error: repo-specific auth material is incomplete for ${repo_name}. Ask the user whether to replace the old auth setup, then rerun prepare with --replace-auth." >&2
    exit 1
  fi

  upsert_ssh_config_block "$repo_name" "$host_alias" "$ssh_key_path"

  if ! test_git_remote_auth "$git_ssh_remote"; then
    echo "Error: GitHub authentication test failed for ${normalized_repo_url}. Ensure the deploy key was added to the target repo and rerun finalize." >&2
    exit 1
  fi

  if [[ -e "$clone_path" ]]; then
    if [[ "$REPLACE_CLONE" != "1" ]]; then
      echo "Error: clone target already exists at workspace/repos/${repo_name}. Ask the user whether to remove the old clone and recreate it, then rerun finalize with --replace-clone." >&2
      exit 1
    fi

    rm -rf "$clone_path"
  fi

  git clone "$git_ssh_remote" "$clone_path"

  echo "GitHub repo authenticated and cloned:"
  echo "  ${normalized_repo_url}"
  echo "Clone path:"
  echo "  workspace/repos/${repo_name}"
  echo "Origin:"
  echo "  $(git -C "$clone_path" remote get-url origin)"
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

case "$1" in
  -h|--help)
    usage
    exit 0
    ;;
esac

MODE="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github-repo-url)
      if [[ $# -lt 2 ]]; then
        echo "Error: --github-repo-url requires a value" >&2
        usage >&2
        exit 1
      fi
      GITHUB_REPO_URL="$2"
      shift 2
      ;;
    --replace-auth)
      REPLACE_AUTH="1"
      shift
      ;;
    --replace-clone)
      REPLACE_CLONE="1"
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

if [[ -z "$GITHUB_REPO_URL" ]]; then
  echo "Error: --github-repo-url is required" >&2
  usage >&2
  exit 1
fi

GITHUB_REPO_URL="$(normalize_github_repo_url "$GITHUB_REPO_URL")"

case "$MODE" in
  prepare)
    if [[ "$REPLACE_CLONE" == "1" ]]; then
      echo "Error: --replace-clone is only valid with finalize" >&2
      exit 1
    fi
    prepare_auth "$GITHUB_REPO_URL"
    ;;
  finalize)
    if [[ "$REPLACE_AUTH" == "1" ]]; then
      echo "Error: --replace-auth is only valid with prepare" >&2
      exit 1
    fi
    finalize_auth_and_clone "$GITHUB_REPO_URL"
    ;;
  *)
    echo "Error: unknown mode: ${MODE}" >&2
    usage >&2
    exit 1
    ;;
esac
