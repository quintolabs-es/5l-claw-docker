#!/bin/sh
set -eu

# Reset agent runtime state so it comes back like a fresh just-onboarded
# instance, ready to be re-born from a clean slate.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_DIR="$SCRIPT_DIR/.openclaw"
SESSIONS_DIR="$STATE_DIR/agents/main/sessions"
TASKS_DIR="$STATE_DIR/tasks"
TASK_DIR="$STATE_DIR/task"

if [ ! -d "$SESSIONS_DIR" ]; then
  printf 'sessions directory not found: %s\n' "$SESSIONS_DIR" >&2
  exit 1
fi

printf '%s\n' 'This will delete all contents of:'
printf '  %s\n' "$SESSIONS_DIR"
[ -d "$TASKS_DIR" ] && printf '  %s\n' "$TASKS_DIR"
[ -d "$TASK_DIR" ] && printf '  %s\n' "$TASK_DIR"
printf '%s\n' 'The agent will refresh and start again like it was just onboarded.'
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
[ -d "$TASKS_DIR" ] && find "$TASKS_DIR" -mindepth 1 -print -exec rm -rf {} +
[ -d "$TASK_DIR" ] && find "$TASK_DIR" -mindepth 1 -print -exec rm -rf {} +

printf 'Journey-to-seed complete. Restart gateway and the agent should start fresh again. \n'
