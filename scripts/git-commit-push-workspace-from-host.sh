#!/usr/bin/env bash
set -euo pipefail

# Use to commit and push workspace change from the host, without needing to open a terminal in docker
# (the git repo to push workspace is authenticated from withing docker compose, git push fails from the host)
# Usage:
#   bash ./scripts/git-commit-push-workspace-from-host.sh "<commit-message>"

usage() {
  cat <<'EOF'
Usage: git-commit-push-workspace-from-host.sh "<commit-message>"
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

COMMIT_MESSAGE="$1"

docker compose run --rm --no-deps --entrypoint bash openclaw-standalone-cli -lc "
  cd /home/node/.openclaw
  git add .
  if git diff --cached --quiet; then
    echo 'No workspace changes to commit.'
    exit 0
  fi
  git commit -m \"\$1\"
  git push origin HEAD
" bash "$COMMIT_MESSAGE"
