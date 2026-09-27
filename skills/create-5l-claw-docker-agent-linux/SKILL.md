---
name: create-5l-claw-docker-agent-linux
description: Create and configure an OpenClaw Docker agent on Linux Mint using 5l-claw-docker. Use when another skill or user provides the agent folder, workspace-backup choice, and optional Telegram setup.
---

# Create 5L Claw Docker Agent (Linux)

Use this skill only on Linux Mint when another skill or user needs the technical OpenClaw Docker creation flow implemented with `5l-claw-docker`.

This skill is technical. It does not decide Meta Garra conventions such as agent naming policy, GitHub owner, repository visibility, or whether a user wants backup or Telegram. Those decisions must be supplied by the caller.

## Inputs

Required:

- `agent-dir`: target path that does not yet exist.
- `workspace-backup`: `yes` or `no`.
- `telegram`: `yes` or `no`.

Optional, depending on choices:

- `workspace-repo-url`: HTTPS GitHub repo URL when `workspace-backup` is `yes`.
- `git-name` and `git-email` for workspace commits when backup is enabled.
- `telegram-bot-token` when `telegram` is `yes`.
- `port` when the caller has already selected a specific gateway port.

## Workflow

1. Read the available versions. Do not infer or select a version yourself:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/get-openclaw-versions-linux.sh
```

Interpret its stable output:

- If `latest_status=available` and the versions differ, present exactly:
  1. Install the configured version: `<configured_version>`.
  2. Install the latest version: `<latest_version>`.
  3. Cancel.
- If `latest_status=available` and the versions match, present exactly:
  1. Install version `<configured_version>`.
  2. Cancel.
- If `latest_status=not_published` or `latest_status=query_failed`, present exactly:
  1. Install the configured version: `<configured_version>`.
  2. Cancel.

Wait for an unambiguous answer. Do not choose a default. Stop on cancellation.

2. Create the harness with the version explicitly selected by the user. Do not reconstruct the `5l-claw-docker` command sequence ad hoc:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/create-5l-claw-docker-agent-linux-harness.sh \
  --agent-dir <path> \
  --openclaw-version <selected-version> \
  [--port <port>]
```

The harness applies and verifies the selected version before reporting success.

3. Tell the user to open a terminal in `<path>` and run:

```bash
docker compose run --rm --no-deps --entrypoint openclaw openclaw-standalone-cli onboard --mode local --no-install-daemon
```

4. Tell the user to complete the wizard. When OpenClaw opens its terminal CLI, they must type `/exit`, then notify you that onboarding is complete.

5. Only after the user confirms, complete creation:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/complete-5l-claw-docker-agent-linux.sh \
  --agent-dir <path> \
  --workspace-backup <yes|no> \
  --telegram <yes|no> \
  [--workspace-repo-url <https-url>] \
  [--git-name <name>] \
  [--git-email <email>] \
  [--telegram-bot-token <token>] \
  [--github-ssh-host-alias <alias>]
```

6. If Telegram is enabled, the completion script configures the channel but does not approve pairing. After the user provides a pairing code, approve it with:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/approve-telegram-pairing-linux.sh \
  --agent-dir <path> \
  --pairing-code <code>
```

## Boundaries

- Do not create GitHub repositories here.
- Do not decide backup, Telegram, naming, or local folder conventions here.
- Treat `5l-claw-docker` as the source for the technical installation flow.
- Read [references/5l-claw-docker-linux.md](references/5l-claw-docker-linux.md) when troubleshooting or changing scripts.
