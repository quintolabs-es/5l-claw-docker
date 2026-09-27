#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TEMPLATE_DOCKERFILE_URL="https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/Dockerfile"
DEFAULT_DIST_TAGS_URL="https://registry.npmjs.org/-/package/openclaw/dist-tags"

template_dockerfile_url="$DEFAULT_TEMPLATE_DOCKERFILE_URL"
dist_tags_url="$DEFAULT_DIST_TAGS_URL"

usage() {
  cat <<'EOF'
Usage:
  get-openclaw-versions-linux.sh [--template-dockerfile-url <url>] [--dist-tags-url <url>]

Output:
  configured_version=<version>
  latest_status=available|not_published|query_failed
  latest_version=<version-or-empty>

Exit codes:
  0  Configured version read successfully; latest_status describes the latest query.
  1  Configured version could not be read or is invalid.
  2  Invalid arguments.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

validate_version() {
  local version="$1"

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]
}

extract_configured_version() {
  sed -n 's/^ARG[[:space:]][[:space:]]*OPENCLAW_VERSION=\([^[:space:]]*\).*$/\1/p' | head -n 1
}

extract_latest_version() {
  sed -n 's/.*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template-dockerfile-url)
      [[ $# -ge 2 ]] || {
        echo "Error: --template-dockerfile-url requires a value" >&2
        usage >&2
        exit 2
      }
      template_dockerfile_url="$2"
      shift 2
      ;;
    --dist-tags-url)
      [[ $# -ge 2 ]] || {
        echo "Error: --dist-tags-url requires a value" >&2
        usage >&2
        exit 2
      }
      dist_tags_url="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

template_dockerfile="$(curl -fsSL "$template_dockerfile_url")" || fail "could not read the template Dockerfile"
configured_version="$(printf '%s\n' "$template_dockerfile" | extract_configured_version)"

[[ -n "$configured_version" ]] || fail "template Dockerfile does not define OPENCLAW_VERSION"
validate_version "$configured_version" || fail "template Dockerfile defines an invalid OpenClaw version: ${configured_version}"

latest_status="available"
latest_version=""

if ! dist_tags_json="$(curl -fsSL "$dist_tags_url")"; then
  latest_status="query_failed"
elif ! latest_version="$(printf '%s\n' "$dist_tags_json" | extract_latest_version)"; then
  latest_status="not_published"
elif [[ -z "$latest_version" ]]; then
  latest_status="not_published"
elif ! validate_version "$latest_version"; then
  latest_status="not_published"
  latest_version=""
fi

printf 'configured_version=%s\n' "$configured_version"
printf 'latest_status=%s\n' "$latest_status"
printf 'latest_version=%s\n' "$latest_version"
