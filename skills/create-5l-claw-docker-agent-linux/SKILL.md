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

1. Create the harness. Do not reconstruct the `5l-claw-docker` command sequence ad hoc:

```bash
skills/create-5l-claw-docker-agent-linux/scripts/create-5l-claw-docker-agent-linux-harness.sh \
  --agent-dir <path> \
  [--port <port>]
```

2. Tell the user to open a terminal in `<path>` and run:

```bash
docker compose run --rm --no-deps --entrypoint openclaw openclaw-standalone-cli onboard --mode local --no-install-daemon
```

3. Tell the user to complete the wizard. When OpenClaw opens its terminal CLI, they must type `/exit`, then notify you that onboarding is complete.

4. Only after the user confirms, complete creation:

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

5. If Telegram is enabled, the completion script configures the channel but does not approve pairing. After the user provides a pairing code, approve it with:

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
