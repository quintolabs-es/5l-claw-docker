#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_REPO_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)

cd "$STATE_REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: .openclaw is not a git repo. Complete onboard first." >&2
  exit 1
fi

stage_if_exists_or_tracked() {
  local path

  for path in "$@"; do
    if [ -e "$path" ] || git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
      git add -A -- "$path"
    fi
  done
}

stage_if_exists_or_tracked \
  ".gitignore" \
  "workspace"

if git diff --cached --quiet; then
  echo "No workspace backup changes to commit."
  exit 0
fi

git commit -m "backup workspace"

if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin HEAD
elif git remote | grep -q .; then
  git push
fi
