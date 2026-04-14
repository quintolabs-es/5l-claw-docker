#!/usr/bin/env bash
set -euo pipefail

# Packages the durable agent state listed in ../state.include and uploads it to
# Google Drive under backups/<project-name>/. This script assumes `gog` is
# already installed and authenticated with Drive write access.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
STATE_REPO_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/../../.." && pwd)
INCLUDE_FILE="${SCRIPT_DIR}/../state.include"
PROJECT_NAME="__PROJECT_NAME__"
BACKUPS_FOLDER_NAME="backups"
ARCHIVE_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FOLDER_NAME="${ARCHIVE_TIMESTAMP}-backup"
ARCHIVE_NAME="state-backup.tar.gz"
TMP_DIR=""

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

trap cleanup EXIT

trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

escape_drive_query_literal() {
  printf '%s' "$1" | sed "s/'/\\\\'/g"
}

json_first_id_from_stdin() {
  node -e '
const fs = require("fs");
const text = fs.readFileSync(0, "utf8").trim();
if (!text) {
  process.exit(0);
}
const data = JSON.parse(text);
const items = Array.isArray(data)
  ? data
  : Array.isArray(data?.files)
    ? data.files
    : Array.isArray(data?.items)
      ? data.items
      : data && typeof data === "object"
        ? [data]
        : [];
const first = items[0];
const id = first && (first.id || first.fileId || first.ID);
if (id) {
  process.stdout.write(String(id));
}
'
}

find_drive_folder_id() {
  local folder_name="$1"
  local parent_id="${2:-}"
  local escaped_name query json

  escaped_name="$(escape_drive_query_literal "$folder_name")"
  query="name='${escaped_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"

  if [[ -n "$parent_id" ]]; then
    query="${query} and '${parent_id}' in parents"
  else
    query="${query} and 'root' in parents"
  fi

  json="$(gog drive search "$query" --max 20 --json --results-only)"
  printf '%s' "$json" | json_first_id_from_stdin
}

ensure_drive_folder_id() {
  local folder_name="$1"
  local parent_id="${2:-}"
  local folder_id json

  folder_id="$(find_drive_folder_id "$folder_name" "$parent_id")"
  if [[ -n "$folder_id" ]]; then
    printf '%s\n' "$folder_id"
    return 0
  fi

  if [[ -n "$parent_id" ]]; then
    json="$(gog drive mkdir "$folder_name" --parent "$parent_id" --json --results-only)"
  else
    json="$(gog drive mkdir "$folder_name" --json --results-only)"
  fi

  printf '%s' "$json" | json_first_id_from_stdin
}

add_literal_path() {
  local relative_path="$1"

  if [[ -e "$relative_path" ]]; then
    ARCHIVE_PATHS+=("$relative_path")
  else
    echo "Skipping missing path: ${relative_path}"
  fi
}

add_glob_paths() {
  local pattern="$1"
  local matches=()

  shopt -s nullglob dotglob
  matches=( $pattern )
  shopt -u nullglob dotglob

  if [[ ${#matches[@]} -eq 0 ]]; then
    echo "Skipping missing path pattern: ${pattern}"
    return 0
  fi

  ARCHIVE_PATHS+=("${matches[@]}")
}

declare -a ARCHIVE_PATHS=()

cd "$STATE_REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: .openclaw is not a git repo. Complete onboard first." >&2
  exit 1
fi

if [[ ! -f "$INCLUDE_FILE" ]]; then
  echo "Error: state include file not found: ${INCLUDE_FILE}" >&2
  exit 1
fi

if ! command -v gog >/dev/null 2>&1; then
  echo "Error: gog is not installed in this container." >&2
  exit 1
fi

if ! gog drive ls --max 1 --plain >/dev/null 2>&1; then
  echo "Error: gog is not ready for Google Drive access. Authenticate it first." >&2
  exit 1
fi

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim_whitespace "$raw_line")"

  if [[ -z "$line" || "$line" == \#* ]]; then
    continue
  fi

  case "$line" in
    *[\*\?\[]*)
      add_glob_paths "$line"
      ;;
    *)
      add_literal_path "$line"
      ;;
  esac
done < "$INCLUDE_FILE"

if [[ ${#ARCHIVE_PATHS[@]} -eq 0 ]]; then
  echo "Error: no files matched state.include; nothing to back up." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"

tar -czf "$ARCHIVE_PATH" "${ARCHIVE_PATHS[@]}"

BACKUPS_FOLDER_ID="$(ensure_drive_folder_id "$BACKUPS_FOLDER_NAME")"
PROJECT_FOLDER_ID="$(ensure_drive_folder_id "$PROJECT_NAME" "$BACKUPS_FOLDER_ID")"
BACKUP_FOLDER_ID="$(ensure_drive_folder_id "$BACKUP_FOLDER_NAME" "$PROJECT_FOLDER_ID")"
UPLOAD_JSON="$(gog drive upload "$ARCHIVE_PATH" --parent "$BACKUP_FOLDER_ID" --name "$ARCHIVE_NAME" --json --results-only)"
UPLOAD_ID="$(printf '%s' "$UPLOAD_JSON" | json_first_id_from_stdin)"

echo "Uploaded: ${BACKUPS_FOLDER_NAME}/${PROJECT_NAME}/${BACKUP_FOLDER_NAME}/${ARCHIVE_NAME}"
if [[ -n "$UPLOAD_ID" ]]; then
  echo "Drive file ID: ${UPLOAD_ID}"
fi
