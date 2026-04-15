# Telegram Access

This runbook is for OpenClaw instances created from this Docker template.

Use this when you want to talk to the agent through Telegram.

## Create The Bot In BotFather

1. Open Telegram and chat with `@BotFather`.
2. Run `/newbot`.
3. Follow the prompts.
4. Save the bot token.

Optional for group usage:
- If the bot must see non-mention messages in groups, run `/setprivacy` in `@BotFather` and disable privacy mode.
- After changing privacy mode, remove and re-add the bot to the group.

## Start The Gateway

The gateway and local CLI already use the token persisted by `complete-onboard.sh`.

```bash
docker compose up -d openclaw-gateway
```

## Open The Gateway CLI

```bash
docker compose run --rm openclaw-gateway-cli
```

## Configure Telegram

Inside the gateway CLI container:

```bash
openclaw channels add --channel telegram --token <bot-token>
openclaw channels status --probe
```

`channels status --probe` is the live check. It confirms the gateway can reach the configured Telegram account.

## Approve The First DM

Default Telegram DM policy is pairing.

1. In Telegram, send a message to the bot from the Telegram account that should own or use the assistant.
2. The bot replies with a pairing code.
3. Back in the gateway CLI container, approve it:

```bash
openclaw pairing list telegram
openclaw pairing approve telegram <PAIRING_CODE>
```

## Test It

Inside the gateway CLI container:

```bash
openclaw message send --channel telegram --target <chat-id-or-@username> "Telegram is connected."
```

For a simple owner-only setup, sending to your own Telegram username is usually enough:

- `--target @yourusername`

## Group Usage

Default group behavior is stricter than DMs.

- Telegram group access is controlled separately from DM pairing.
- If commands should work only when the bot is mentioned, the default group behavior is usually fine.
- If the bot should react without mentions in a group, disable BotFather privacy mode first.

If you want Telegram heartbeat replies, complete Telegram setup first and then set the heartbeat target in [README.onboard.md](./README.onboard.md).
