#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"
SUDO=""

if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi

log() {
  printf '%s\n' "$1"
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_supported_host() {
  local architecture
  local bitness

  architecture="$(dpkg --print-architecture)"
  bitness="$(getconf LONG_BIT)"

  if [[ "$architecture" != "arm64" ]]; then
    fail "This script supports Raspberry Pi arm64 only. Detected architecture: ${architecture}."
  fi

  if [[ "$bitness" != "64" ]]; then
    fail "This script requires a 64-bit operating system. Detected: ${bitness}-bit."
  fi

  if [[ ! -r /etc/os-release ]]; then
    fail "Could not read /etc/os-release."
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  if [[ -z "${VERSION_CODENAME:-}" ]]; then
    fail "Could not detect VERSION_CODENAME from /etc/os-release."
  fi

  case "${ID:-}" in
    debian|raspbian)
      ;;
    *)
      if [[ "${ID_LIKE:-}" != *debian* ]]; then
        fail "This script expects a Debian-family OS. Detected ID=${ID:-unknown}."
      fi
      ;;
  esac
}

install_prerequisites() {
  export DEBIAN_FRONTEND=noninteractive

  log "Installing Docker prerequisites..."
  $SUDO apt-get update
  $SUDO apt-get install -y ca-certificates curl
}

configure_docker_repository() {
  local architecture
  local docker_source_file

  # shellcheck disable=SC1091
  . /etc/os-release
  architecture="$(dpkg --print-architecture)"

  log "Configuring Docker package repository..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  $SUDO curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc

  docker_source_file="$(mktemp)"
  cat > "$docker_source_file" <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: ${architecture}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  $SUDO install -m 0644 "$docker_source_file" /etc/apt/sources.list.d/docker.sources
  rm -f "$docker_source_file"
}

install_docker() {
  log "Installing Docker Engine and Compose plugin..."
  $SUDO apt-get update
  $SUDO apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  $SUDO systemctl enable --now docker
}

configure_docker_group() {
  if ! getent group docker >/dev/null 2>&1; then
    $SUDO groupadd docker
  fi

  if [[ "$TARGET_USER" != "root" ]]; then
    log "Adding ${TARGET_USER} to the docker group..."
    $SUDO usermod -aG docker "$TARGET_USER"
  fi
}

verify_installation() {
  log "Verifying Docker with sudo..."
  $SUDO docker run --rm hello-world
}

print_next_step() {
  log ""
  log "Docker installation completed."

  if [[ "$TARGET_USER" == "root" ]]; then
    log "Verify Docker with: docker run --rm hello-world"
    return
  fi

  log "Log out and log back in before using Docker without sudo."
  log "After logging back in, verify with: docker run --rm hello-world"
}

main() {
  require_supported_host
  install_prerequisites
  configure_docker_repository
  install_docker
  configure_docker_group
  verify_installation
  print_next_step
}

main "$@"
