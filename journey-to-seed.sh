#!/bin/sh
set -eu

# USAGE: ./journey-to-seed.sh

# Reset runtime state so the agent comes back like a fresh just-onboarded instance.
#
# This script deletes the contents of:
# - .openclaw/agents/*/sessions
# - .openclaw/tasks
# - .openclaw/media
# - .openclaw/memory
# - .openclaw/logs
# - .openclaw/completions

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

STATE_DIR="$SCRIPT_DIR/.openclaw"

AGENTS_DIR="$STATE_DIR/agents"

CLEAN_DIRS="
$STATE_DIR/tasks
$STATE_DIR/media
$STATE_DIR/memory
$STATE_DIR/logs
$STATE_DIR/completions
"

printf '%s\n' 'This will delete all contents of:'

if [ -d "$AGENTS_DIR" ]; then
  for session_dir in "$AGENTS_DIR"/*/sessions; do
    if [ -d "$session_dir" ]; then
      printf '  %s\n' "$session_dir"
    fi
  done
else
  printf '  %s (not found, skipping)\n' "$AGENTS_DIR"
fi

printf '%s' "$CLEAN_DIRS" | while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  if [ -d "$dir" ]; then
    printf '  %s\n' "$dir"
  else
    printf '  %s (not found, skipping)\n' "$dir"
  fi
done

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

if [ -d "$AGENTS_DIR" ]; then
  for session_dir in "$AGENTS_DIR"/*/sessions; do
    if [ -d "$session_dir" ]; then
      find "$session_dir" -mindepth 1 -print -exec rm -rf {} +
    fi
  done
fi

printf '%s' "$CLEAN_DIRS" | while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  [ -d "$dir" ] && find "$dir" -mindepth 1 -print -exec rm -rf {} +
done

printf 'Journey-to-seed complete. Restart gateway and the agent should start fresh again. \n'
