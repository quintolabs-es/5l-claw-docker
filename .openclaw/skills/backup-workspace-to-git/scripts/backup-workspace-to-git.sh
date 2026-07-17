#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_REPO_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)

cd "$STATE_REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: .openclaw is not a git repo. Complete onboard first." >&2
  exit 1
fi

git add -A .

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
