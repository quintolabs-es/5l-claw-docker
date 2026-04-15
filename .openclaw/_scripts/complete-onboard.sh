#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   /home/node/.openclaw/_scripts/complete-onboard.sh [--github-remote-url <https://github.com/owner/repo>] [--git-name <name>] [--git-email <email>]

GATEWAY_PORT="18789"
GIT_NAME="La Garra"
GIT_EMAIL="lagarra@quintolabs.es"
GITHUB_REPO_URL=""

usage() {
  cat <<'EOF'
Usage: complete-onboard.sh [--github-remote-url <https://github.com/owner/repo>] [--git-name <name>] [--git-email <email>]
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
    echo "Error: --github-remote-url must be in the form https://github.com/<owner>/<repo>" >&2
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github-remote-url)
      if [[ $# -lt 2 ]]; then
        echo "Error: --github-remote-url requires a value" >&2
        usage >&2
        exit 1
      fi
      GITHUB_REPO_URL="$2"
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

# remove the git repo OpenClaw creates inside workspace
rm -rf /home/node/.openclaw/workspace/.git

# configure Gateway For Docker
openclaw config set gateway.mode local
openclaw config set gateway.bind lan
openclaw config set gateway.port "$GATEWAY_PORT" --strict-json
openclaw config set gateway.controlUi.allowedOrigins "[\"http://localhost:${GATEWAY_PORT}\",\"http://127.0.0.1:${GATEWAY_PORT}\"]" --strict-json

# initialize the repo-local durable state
cd /home/node/.openclaw
git init
git config user.name "$GIT_NAME"
git config user.email "$GIT_EMAIL"
git add .
if ! git diff --cached --quiet; then
  git commit -m "initial commit after onboard"
fi

# optional: add a GitHub remote origin and prepare SSH access
if [[ -n "$GITHUB_REPO_URL" ]]; then
  GIT_SSH_REMOTE="$(build_github_ssh_remote "$GITHUB_REPO_URL")"
  ensure_ssh_material

  if git remote get-url origin >/dev/null 2>&1; then
    if [[ "$(git remote get-url origin)" != "$GIT_SSH_REMOTE" ]]; then
      echo "Error: existing origin does not match requested GitHub remote." >&2
      exit 1
    fi
  else
    git remote add origin "$GIT_SSH_REMOTE"
  fi

  echo "Remote origin configured:"
  echo "  $GIT_SSH_REMOTE"
  echo "Add the public key in GitHub as a deploy key with write access, then run:"
  echo "  git push -u origin HEAD"
fi
