#!/bin/sh
set -eu

# Delete persisted main-agent session files to force a cold start.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SESSIONS_DIR="$SCRIPT_DIR/.openclaw/agents/main/sessions"

if [ ! -d "$SESSIONS_DIR" ]; then
  printf 'sessions directory not found: %s\n' "$SESSIONS_DIR" >&2
  exit 1
fi

printf 'This will delete all contents of: %s\n' "$SESSIONS_DIR"
printf '%s\n' 'The agent will refresh and start again like new.'
printf '%s' 'Press Enter to confirm. Press Escape or any other key to abort: '

IFS= read -r -n 1 CONFIRM_KEY || true

if [ "${CONFIRM_KEY:-}" = "$(printf '\033')" ]; then
  printf '\n%s\n' 'Aborted.'
  exit 0
fi

if [ -n "${CONFIRM_KEY:-}" ]; then
  printf '\n%s\n' 'Aborted.'
  exit 0
fi

printf '\n'
find "$SESSIONS_DIR" -mindepth 1 -print -exec rm -rf {} +

printf 'Journey-to-seed complete. Restart gateway and the agent should start fresh again. \n'
