# Raspberry Pi Setup

This file captures the Raspberry Pi setup steps for a new agent. Add the next steps here as the setup continues.

## 1. Set up Raspberry Pi OS and connect over SSH

```bash
ssh <user>@<raspberry-domainname>.local
```

## 2. Confirm the Pi is on 64-bit arm64

```bash
dpkg --print-architecture
getconf LONG_BIT
```

Expected output:

```text
arm64
64
```

## 3. Install Docker and enable non-sudo Docker usage

```bash
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/install-docker-raspberry.sh?skip-cache=$(date +%s)" | bash
```

The installer script:

- installs Docker Engine and the Docker Compose plugin
- adds the current user to the `docker` group
- verifies the install with `sudo docker run --rm hello-world`

When the script finishes, log out and log back in. Then verify Docker without `sudo`:

```bash
docker run --rm hello-world
```
