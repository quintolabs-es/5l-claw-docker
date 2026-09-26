# 5l-claw-docker Linux Reference

Use this reference when creating or troubleshooting Meta Garra OpenClaw agents.

## Source

- Repository: `https://github.com/quintolabs-es/5l-claw-docker`
- Standard Docker script:
  `https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/claw-docker.sh`

## Standard Init

Run from an empty agent folder:

```bash
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/claw-docker.sh?skip-cache=$(date +%s)" | bash -s -- init --port <port>
```

`init` creates the Docker harness and managed OpenClaw folders. The default gateway port is `18789`; multiple agents on the same machine need distinct host ports.

## Build

```bash
docker compose build
```

## Interactive Onboard

Tell the user to open a terminal in the agent folder and run:

```bash
docker compose run --rm --no-deps --entrypoint openclaw openclaw-standalone-cli onboard --mode local --no-install-daemon
```

The user completes the wizard. When OpenClaw opens its terminal CLI, they type `/exit`, then notify the creating agent to continue.

## Complete Onboard

For an agent with a new workspace backup repository:

```bash
bash _scripts/complete-onboard.sh \
  --gateway-token <token> \
  --github-remote-url-new-workspace <https://github.com/owner/repo> \
  --git-name "Meta Garra" \
  --git-email la.meta.garra@gmail.com
```

For an agent without workspace backup:

```bash
bash _scripts/complete-onboard.sh --gateway-token <token>
```

If the caller provides a GitHub SSH host alias, and the generated `complete-onboard.sh` exposes a `GITHUB_SSH_HOST_ALIAS` variable, set it before completing onboarding.

## Start Gateway

```bash
docker compose up -d openclaw-gateway
```

Gateway URL:

```text
http://localhost:<port>/
```

## Services

- `openclaw-standalone-cli`: onboarding, backup, restore, local maintenance.
- `openclaw-gateway`: long-running gateway.
- `openclaw-gateway-cli`: on-demand CLI sharing gateway network namespace.

## Telegram

The technical skill executes Telegram setup through scripts, not ad hoc command reconstruction.

Configure the Telegram channel with:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/configure-telegram-linux.sh \
  --agent-dir <agent-folder> \
  --bot-token <bot-token>
```

That script runs the official OpenClaw sequence inside `openclaw-gateway-cli`:

```bash
openclaw channels add --channel telegram --token <bot-token>
openclaw channels status --probe
openclaw config set channels.telegram.streaming.mode off
```

After the user sends a message to the Telegram bot and provides the pairing code, approve it with:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/approve-telegram-pairing-linux.sh \
  --agent-dir <agent-folder> \
  --pairing-code <code>
```

That script runs:

```bash
openclaw pairing approve telegram <PAIRING_CODE>
```
