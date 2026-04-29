#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   /home/node/.openclaw/_scripts/complete-onboard.sh --gateway-token <token> [--github-remote-url-new-workspace <https://github.com/owner/repo>] [--github-remote-url-existing-workspace <https://github.com/owner/repo>] [--git-name <name>] [--git-email <email>]

GATEWAY_PORT="18789"
GATEWAY_TOKEN=""
GIT_NAME="La Garra"
GIT_EMAIL="lagarra@quintolabs.es"
GITHUB_REPO_URL_NEW_WORKSPACE=""
GITHUB_REPO_URL_EXISTING_WORKSPACE=""
GITHUB_SSH_HOST_ALIAS="github.com-openclaw"
OPENCLAW_SSH_KEY_BASENAME="openclaw_github_ed25519"

usage() {
  cat <<'EOF'
Usage: complete-onboard.sh --gateway-token <token> [--github-remote-url-new-workspace <https://github.com/owner/repo>] [--github-remote-url-existing-workspace <https://github.com/owner/repo>] [--git-name <name>] [--git-email <email>]
EOF
}

print_github_deploy_key_instructions() {
  local public_key_host_path="$1"

  if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
    printf '\033[32m'
  fi

  cat <<EOF
GitHub deploy key setup:
  1. Open the target GitHub repository.
  2. Go to Settings.
  3. Go to Deploy keys.
  4. Click Add deploy key.
  5. Paste the contents of:
     ${public_key_host_path}
  6. Enable write access.
  7. Save.
EOF

  if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
    printf '\033[0m'
  fi
}

build_github_ssh_remote() {
  local repo_url="$1"
  local normalized path

  normalized="${repo_url%.git}"
  normalized="${normalized%/}"

  if [[ ! "$normalized" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
    echo "Error: GitHub remote URL must be in the form https://github.com/<owner>/<repo>" >&2
    exit 1
  fi

  path="${normalized#https://github.com/}"
  printf 'git@%s:%s.git\n' "$GITHUB_SSH_HOST_ALIAS" "$path"
}

configure_gateway_for_docker() {
  openclaw config set gateway.mode local
  openclaw config set gateway.bind lan
  openclaw config set gateway.port "$GATEWAY_PORT" --strict-json
  openclaw config set gateway.auth.mode token
  openclaw config set gateway.auth.token "$GATEWAY_TOKEN"
  openclaw config set gateway.remote.token "$GATEWAY_TOKEN"
  openclaw config set gateway.controlUi.allowedOrigins "[\"http://localhost:${GATEWAY_PORT}\",\"http://127.0.0.1:${GATEWAY_PORT}\"]" --strict-json
}

configure_git_identity() {
  git config user.name "$GIT_NAME"
  git config user.email "$GIT_EMAIL"
}

configure_origin_remote() {
  local git_ssh_remote="$1"

  if git remote get-url origin >/dev/null 2>&1; then
    if [[ "$(git remote get-url origin)" != "$git_ssh_remote" ]]; then
      echo "Error: existing origin does not match requested GitHub remote." >&2
      exit 1
    fi
  else
    git remote add origin "$git_ssh_remote"
  fi
}

ensure_known_hosts() {
  local ssh_known_hosts_path="$1"

  if [[ ! -f "$ssh_known_hosts_path" ]] || ! grep -q '^github\.com ' "$ssh_known_hosts_path"; then
    touch "$ssh_known_hosts_path"
    ssh-keyscan github.com >> "$ssh_known_hosts_path" 2>/dev/null
  fi
}

write_ssh_config() {
  local ssh_config_path="$1"
  local ssh_key_path="$2"

  cat > "$ssh_config_path" <<EOF
Host ${GITHUB_SSH_HOST_ALIAS}
  HostName github.com
  User git
  IdentityFile ${ssh_key_path}
  IdentitiesOnly yes
EOF
}

openclaw_ssh_key_path() {
  local ssh_dir="$HOME/.ssh"
  printf '%s/%s\n' "$ssh_dir" "$OPENCLAW_SSH_KEY_BASENAME"
}

test_git_remote_auth() {
  local git_ssh_remote="$1"

  git ls-remote "$git_ssh_remote" >/dev/null 2>&1
}

print_public_key_info() {
  local ssh_pub_key_path="$1"
  local public_key_host_path="./.openclaw/_secrets/git/.ssh/$(basename "$ssh_pub_key_path")"

  echo "GitHub deploy public key:"
  echo "  $ssh_pub_key_path"
  echo "Host path:"
  echo "  ${public_key_host_path}"
  echo
  print_github_deploy_key_instructions "${public_key_host_path}"
}

prompt_for_deploy_key_completion() {
  local response=""

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Error: GitHub remote setup requires an interactive terminal so you can add the deploy key and continue." >&2
    exit 1
  fi

  printf "Press Enter after completing the deploy key setup in GitHub, or Ctrl+C to abort."
  IFS= read -r response || true
}

ensure_authenticated_ssh_material() {
  local git_ssh_remote="$1"
  local ssh_dir="$HOME/.ssh"
  local ssh_key_path=""
  local ssh_pub_key_path=""
  local ssh_config_path="$ssh_dir/config"
  local ssh_known_hosts_path="$ssh_dir/known_hosts"
  local backup_suffix=""

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  touch "$ssh_known_hosts_path"
  chmod 600 "$ssh_known_hosts_path"
  ensure_known_hosts "$ssh_known_hosts_path"

  ssh_key_path="$(openclaw_ssh_key_path)"
  ssh_pub_key_path="${ssh_key_path}.pub"

  if [[ -f "$ssh_key_path" ]]; then
    write_ssh_config "$ssh_config_path" "$ssh_key_path"
    chmod 600 "$ssh_config_path"
    if test_git_remote_auth "$git_ssh_remote"; then
      return 0
    fi

    backup_suffix="$(date +%Y%m%d-%H%M%S)"
    mv "$ssh_key_path" "${ssh_key_path}.bak-${backup_suffix}"
    if [[ -f "$ssh_pub_key_path" ]]; then
      mv "$ssh_pub_key_path" "${ssh_pub_key_path}.bak-${backup_suffix}"
    fi
  fi

  ssh-keygen -t ed25519 -N "" -C "$GIT_EMAIL" -f "$ssh_key_path" >/dev/null
  write_ssh_config "$ssh_config_path" "$ssh_key_path"
  chmod 600 "$ssh_key_path" "$ssh_config_path" "$ssh_known_hosts_path"
  chmod 644 "$ssh_pub_key_path"

  print_public_key_info "$ssh_pub_key_path"
  prompt_for_deploy_key_completion

  if ! test_git_remote_auth "$git_ssh_remote"; then
    echo "Error: GitHub authentication test failed for ${git_ssh_remote}. Ensure the deploy key was added to the target repo and rerun complete-onboard." >&2
    exit 1
  fi
}

ensure_remote_is_empty_for_new_workspace() {
  local git_ssh_remote="$1"

  if [[ -n "$(git ls-remote --heads --tags "$git_ssh_remote" 2>/dev/null)" ]]; then
    echo "Error: target repo already contains refs. Use --github-remote-url-existing-workspace instead." >&2
    exit 1
  fi
}

detect_remote_head_branch() {
  local branch

  branch="$(git ls-remote --symref origin HEAD 2>/dev/null | awk '/^ref:/ {sub("refs/heads/","",$2); print $2; exit}')"
  if [[ -z "$branch" ]]; then
    echo "Error: could not detect the remote default branch from origin." >&2
    exit 1
  fi

  printf '%s\n' "$branch"
}

setup_new_workspace_repo() {
  git init
  configure_git_identity
  git add .
  if ! git diff --cached --quiet; then
    git commit -m "initial commit after onboard"
  fi
}

attach_existing_workspace_repo() {
  local git_ssh_remote="$1"
  local branch=""

  rm -rf .git workspace .gitignore

  git init
  configure_git_identity
  configure_origin_remote "$git_ssh_remote"

  if ! git fetch origin; then
    echo "Error: failed to fetch origin. Ensure the deploy key has access to the target repo, then rerun complete-onboard." >&2
    exit 1
  fi

  branch="$(detect_remote_head_branch)"
  git checkout -b "$branch" --track "origin/$branch"

  if [[ ! -d workspace || ! -e .gitignore ]]; then
    echo "Error: existing workspace repo must contain workspace/ and .gitignore at the .openclaw repo root." >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gateway-token)
      if [[ $# -lt 2 ]]; then
        echo "Error: --gateway-token requires a value" >&2
        usage >&2
        exit 1
      fi
      GATEWAY_TOKEN="$2"
      shift 2
      ;;
    --github-remote-url-new-workspace)
      if [[ $# -lt 2 ]]; then
        echo "Error: --github-remote-url-new-workspace requires a value" >&2
        usage >&2
        exit 1
      fi
      GITHUB_REPO_URL_NEW_WORKSPACE="$2"
      shift 2
      ;;
    --github-remote-url-existing-workspace)
      if [[ $# -lt 2 ]]; then
        echo "Error: --github-remote-url-existing-workspace requires a value" >&2
        usage >&2
        exit 1
      fi
      GITHUB_REPO_URL_EXISTING_WORKSPACE="$2"
      shift 2
      ;;
    --git-name)
      if [[ $# -lt 2 ]]; then
        echo "Error: --git-name requires a value" >&2
        usage >&2
        exit 1
      fi
      GIT_NAME="$2"
      shift 2
      ;;
    --git-email)
      if [[ $# -lt 2 ]]; then
        echo "Error: --git-email requires a value" >&2
        usage >&2
        exit 1
      fi
      GIT_EMAIL="$2"
      shift 2
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

if [[ -z "$GATEWAY_TOKEN" ]]; then
  echo "Error: --gateway-token is required" >&2
  usage >&2
  exit 1
fi

if [[ -n "$GITHUB_REPO_URL_NEW_WORKSPACE" && -n "$GITHUB_REPO_URL_EXISTING_WORKSPACE" ]]; then
  echo "Error: pass only one of --github-remote-url-new-workspace or --github-remote-url-existing-workspace." >&2
  usage >&2
  exit 1
fi

# remove the git repo OpenClaw creates inside workspace
rm -rf /home/node/.openclaw/workspace/.git

configure_gateway_for_docker

cd /home/node/.openclaw

if [[ -n "$GITHUB_REPO_URL_NEW_WORKSPACE" ]]; then
  GIT_SSH_REMOTE="$(build_github_ssh_remote "$GITHUB_REPO_URL_NEW_WORKSPACE")"
  ensure_authenticated_ssh_material "$GIT_SSH_REMOTE"
  ensure_remote_is_empty_for_new_workspace "$GIT_SSH_REMOTE"
  setup_new_workspace_repo
  configure_origin_remote "$GIT_SSH_REMOTE"
  git push -u origin HEAD

  echo "New workspace remote origin configured:"
  echo "  $GIT_SSH_REMOTE"
  echo "Initial workspace commit pushed to origin."
elif [[ -n "$GITHUB_REPO_URL_EXISTING_WORKSPACE" ]]; then
  GIT_SSH_REMOTE="$(build_github_ssh_remote "$GITHUB_REPO_URL_EXISTING_WORKSPACE")"
  ensure_authenticated_ssh_material "$GIT_SSH_REMOTE"
  attach_existing_workspace_repo "$GIT_SSH_REMOTE"

  echo "Existing workspace remote origin attached:"
  echo "  $GIT_SSH_REMOTE"
else
  setup_new_workspace_repo
fi

echo "Gateway token configured on the gateway and local CLI config, so local CLI commands already use it."
