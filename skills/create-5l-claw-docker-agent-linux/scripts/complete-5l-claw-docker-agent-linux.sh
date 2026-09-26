#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

agent_dir=""
workspace_backup=""
workspace_repo_url=""
git_name=""
git_email=""
telegram=""
telegram_bot_token=""
github_ssh_host_alias=""

usage() {
  cat <<'EOF'
Usage:
  complete-5l-claw-docker-agent-linux.sh --agent-dir <path> --workspace-backup <yes|no> --telegram <yes|no> [options]

Options:
  --workspace-repo-url <https-url>  Required when --workspace-backup yes.
  --git-name <name>                 Required when --workspace-backup yes.
  --git-email <email>               Required when --workspace-backup yes.
  --github-ssh-host-alias <alias>   Optional SSH host alias for workspace Git remotes.
  --telegram-bot-token <token>      Required when --telegram yes.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

validate_yes_no() {
  local label="$1"
  local value="$2"

  case "$value" in
    yes|no) ;;
    "") fail "--${label} is required" ;;
    *) fail "--${label} must be yes or no" ;;
  esac
}

generate_token() {
  local token

  token="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 48 || true)"
  [[ "${#token}" -eq 48 ]] || fail "could not generate gateway token"
  printf '%s\n' "$token"
}

validate_inputs() {
  [[ -n "$agent_dir" ]] || fail "--agent-dir is required"
  [[ -d "$agent_dir" ]] || fail "agent directory not found: ${agent_dir}"
  [[ -f "${agent_dir}/docker-compose.yml" ]] || fail "docker-compose.yml not found in agent directory"
  [[ -f "${agent_dir}/.openclaw/openclaw.json" ]] || fail "OpenClaw onboarding is not complete. Run it before this completion step."
  validate_yes_no "workspace-backup" "$workspace_backup"
  validate_yes_no "telegram" "$telegram"

  if [[ "$workspace_backup" == "yes" ]]; then
    [[ -n "$workspace_repo_url" ]] || fail "--workspace-repo-url is required when --workspace-backup yes"
    [[ -n "$git_name" ]] || fail "--git-name is required when --workspace-backup yes"
    [[ -n "$git_email" ]] || fail "--git-email is required when --workspace-backup yes"
  else
    [[ -z "$workspace_repo_url" ]] || fail "--workspace-repo-url must not be provided when --workspace-backup no"
  fi

  if [[ "$telegram" == "yes" ]]; then
    [[ -n "$telegram_bot_token" ]] || fail "--telegram-bot-token is required when --telegram yes"
  else
    [[ -z "$telegram_bot_token" ]] || fail "--telegram-bot-token must not be provided when --telegram no"
  fi

  if [[ -n "$github_ssh_host_alias" && ! "$github_ssh_host_alias" =~ ^[A-Za-z0-9.-]+$ ]]; then
    fail "--github-ssh-host-alias must contain only letters, digits, dots, or hyphens"
  fi
}

configure_openclaw_github_alias() {
  local onboard_script="${agent_dir}/.openclaw/_scripts/complete-onboard.sh"

  [[ -n "$github_ssh_host_alias" ]] || return 0
  [[ -f "$onboard_script" ]] || fail "complete-onboard.sh not found"
  sed -i "s/^GITHUB_SSH_HOST_ALIAS=\"[^\"]*\"/GITHUB_SSH_HOST_ALIAS=\"${github_ssh_host_alias}\"/" "$onboard_script"
}

complete_onboard() {
  local gateway_token="$1"
  local command=(
    _scripts/complete-onboard.sh
    --gateway-token "$gateway_token"
  )

  if [[ "$workspace_backup" == "yes" ]]; then
    command+=(
      --github-remote-url-new-workspace "$workspace_repo_url"
      --git-name "$git_name"
      --git-email "$git_email"
    )
  fi

  (
    cd "$agent_dir"
    docker compose run --rm --no-deps openclaw-standalone-cli "${command[@]}"
  )
}

start_gateway() {
  (
    cd "$agent_dir"
    docker compose up -d openclaw-gateway
  )
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent-dir)
      [[ $# -ge 2 ]] || fail "--agent-dir requires a value"
      agent_dir="$2"
      shift 2
      ;;
    --workspace-backup)
      [[ $# -ge 2 ]] || fail "--workspace-backup requires a value"
      workspace_backup="$2"
      shift 2
      ;;
    --workspace-repo-url)
      [[ $# -ge 2 ]] || fail "--workspace-repo-url requires a value"
      workspace_repo_url="$2"
      shift 2
      ;;
    --git-name)
      [[ $# -ge 2 ]] || fail "--git-name requires a value"
      git_name="$2"
      shift 2
      ;;
    --git-email)
      [[ $# -ge 2 ]] || fail "--git-email requires a value"
      git_email="$2"
      shift 2
      ;;
    --github-ssh-host-alias)
      [[ $# -ge 2 ]] || fail "--github-ssh-host-alias requires a value"
      github_ssh_host_alias="$2"
      shift 2
      ;;
    --telegram)
      [[ $# -ge 2 ]] || fail "--telegram requires a value"
      telegram="$2"
      shift 2
      ;;
    --telegram-bot-token)
      [[ $# -ge 2 ]] || fail "--telegram-bot-token requires a value"
      telegram_bot_token="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

validate_inputs
require_command docker
require_command sed
docker compose version >/dev/null 2>&1 || fail "Docker Compose is not available as 'docker compose'"

gateway_token="$(generate_token)"
configure_openclaw_github_alias
complete_onboard "$gateway_token"
start_gateway

if [[ "$telegram" == "yes" ]]; then
  "${SCRIPT_DIR}/configure-telegram-linux.sh" --agent-dir "$agent_dir" --bot-token "$telegram_bot_token"
fi

echo "OpenClaw Docker agent completion finished."
