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
  printf 'git@github.com:%s.git\n' "$path"
}

ensure_ssh_material() {
  local ssh_dir="$HOME/.ssh"
  local ssh_key_path="$ssh_dir/id_ed25519"
  local ssh_pub_key_path="$ssh_dir/id_ed25519.pub"
  local ssh_config_path="$ssh_dir/config"
  local ssh_known_hosts_path="$ssh_dir/known_hosts"

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ ! -f "$ssh_key_path" ]]; then
    ssh-keygen -t ed25519 -N "" -C "$GIT_EMAIL" -f "$ssh_key_path" >/dev/null
  fi

  cat > "$ssh_config_path" <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF

  if [[ ! -f "$ssh_known_hosts_path" ]] || ! grep -q '^github\.com ' "$ssh_known_hosts_path"; then
    touch "$ssh_known_hosts_path"
    ssh-keyscan github.com >> "$ssh_known_hosts_path" 2>/dev/null
  fi

  chmod 600 "$ssh_key_path" "$ssh_config_path" "$ssh_known_hosts_path"
  chmod 644 "$ssh_pub_key_path"

  echo "GitHub deploy public key:"
  echo "  $ssh_pub_key_path"
  echo "Host path:"
  echo "  ./.openclaw/_secrets/git/.ssh/id_ed25519.pub"
  echo
  print_github_deploy_key_instructions "./.openclaw/_secrets/git/.ssh/id_ed25519.pub"
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

detect_remote_head_branch() {
  local branch

  branch="$(git ls-remote --symref origin HEAD 2>/dev/null | awk '/^ref:/ {sub("refs/heads/","",$2); print $2; exit}')"
  if [[ -z "$branch" ]]; then
    echo "Error: could not detect the remote default branch from origin." >&2
    exit 1
  fi

  printf '%s\n' "$branch"
}

prompt_existing_workspace_fetch() {
  local response=""

  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Error: --github-remote-url-existing-workspace requires an interactive terminal so you can add the deploy key and confirm before fetching." >&2
    exit 1
  fi

  echo
  echo "The existing workspace repo will now be fetched from origin."
  echo "Add the deploy key in GitHub first, then continue."
  printf "Continue with fetching the existing workspace repo? [y/N] "
  IFS= read -r response || true

  if [[ "$response" != "y" ]]; then
    echo "Aborted before fetching the existing workspace repo." >&2
    exit 1
  fi
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

  prompt_existing_workspace_fetch

  if ! git fetch origin; then
    echo "Error: failed to fetch origin. Ensure the deploy key has been added with access to the target repo, then rerun complete-onboard." >&2
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
  ensure_ssh_material
  setup_new_workspace_repo
  configure_origin_remote "$GIT_SSH_REMOTE"

  echo "New workspace remote origin configured:"
  echo "  $GIT_SSH_REMOTE"
  echo "Add the public key in GitHub as a deploy key with write access, then run:"
  echo "  git push -u origin HEAD"
elif [[ -n "$GITHUB_REPO_URL_EXISTING_WORKSPACE" ]]; then
  GIT_SSH_REMOTE="$(build_github_ssh_remote "$GITHUB_REPO_URL_EXISTING_WORKSPACE")"
  ensure_ssh_material
  attach_existing_workspace_repo "$GIT_SSH_REMOTE"

  echo "Existing workspace remote origin attached:"
  echo "  $GIT_SSH_REMOTE"
else
  setup_new_workspace_repo
fi

echo "Gateway token configured on the gateway and local CLI config, so local CLI commands already use it."
