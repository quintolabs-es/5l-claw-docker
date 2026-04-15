# OpenClaw Onboard
## Build

```bash
docker compose build
```

## Onboard
Use `openclaw-standalone-cli` for `onboard` and initial config. It does not require the gateway to be running. Use `openclaw-gateway-cli` only for commands that talk to the running gateway.

```bash
# open a shell in the standalone CLI container to run onboard
docker compose run --rm --no-deps openclaw-standalone-cli

# run Onboard and go through the setup
openclaw onboard --mode local --no-install-daemon

# complete onboard for Docker and initialize the repo for workspace folder
# --gateway-token is required. It is written to both gateway and local CLI config, so gateway requires it and local CLI commands already use it.
# the git remote is optional. If not provided, no remote push target is configured. name and email already have defaults.
bash _scripts/complete-onboard.sh --gateway-token openclaw-gateway-default-token --github-remote-url https://github.com/owner/repo --git-name "La Garra" --git-email "lagarra@quintolabs.es"
```

### Setup git authentication
If `--github-remote-url` is passed, the complete-onboard script creates SSH files in `./.openclaw/_secrets/git/.ssh/` on the host and mounts them as `~/.ssh` in the Docker containers that need Git access.

Print the generated public key:
```bash
cat ./.openclaw/_secrets/git/.ssh/id_ed25519.pub
```

Add it in GitHub as a deploy key with write access for the target repo:
- Open the target GitHub repository.
- Go to `Settings`.
- Go to `Deploy keys`.
- Click `Add deploy key`.
- Paste the contents of `./.openclaw/_secrets/git/.ssh/id_ed25519.pub`.
- Enable write access.
- Save.

**Then back to the standalone CLI container**, verify push works:
```bash
git push origin head
```

## Additional optional setup

### Google Access
Optional post-onboard setup.

The agent can access Google services such as Gmail, Calendar, and Drive through the `gog` CLI skill. If needed, copy `./.openclaw/_secrets/.env.example` to `./.openclaw/_secrets/.env`, set `GOG_ACCOUNT` and `GOG_KEYRING_PASSWORD`, and then complete [README.google.md](./README.google.md).

### Telegram channel
Optional post-onboard setup.

If this agent should be reachable through Telegram, complete [README.telegram.md](./README.telegram.md) before using Telegram-based heartbeat or normal chat.


### Set Hearbeat and heartbeat response channel
By default hearbit runs every 30m, executes `HEARTBEAT.md` prompt and response (if any) is sent to last channel.
Check `https://docs.openclaw.ai/gateway/heartbeat`.

```bash
openclaw config set agents.defaults.heartbeat.every "30m"
openclaw config set agents.defaults.heartbeat.target "telegram"
openclaw config set agents.defaults.heartbeat.to "telegram"
openclaw config set agents.defaults.heartbeat.activeHours.start "09:00"
openclaw config set agents.defaults.heartbeat.activeHours.end "22:00"
openclaw config set agents.defaults.heartbeat.activeHours.timezone "Europe/Madrid"
```

The value `agents.defaults.heartbeat.target` specifies where to send the heartbeat response/result message, in case there is one.

### Others
Web search
```bash
openclaw configure --section web
```


## Start the Gateway
**Onboarding is complete**, now the gateway can be started.
The gateway and local CLI already use the token persisted by `complete-onboard.sh`.

```bash
docker compose up -d openclaw-gateway
```

Check gateway status from cli
```bash
docker compose run --rm openclaw-gateway-cli
openclaw gateway status
```
_It's expected that `systemd` check fails, because it's not used in docker._

### Test gateway CLI
To run gateway CLI commands, run the gateway CLI container and bash into it. This tests connectivity between `openclaw-gateway-cli` and the running gateway.
```bash
docker compose run --rm openclaw-gateway-cli
# test it 
openclaw devices list
```

## Setup Control UI (paring)
Browse to `http://localhost:18789/` 
Or run in CLI
```bash
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

### First time open Control UI: Device pairing required
[Official doc](https://docs.openclaw.ai/web/control-ui#device-pairing-first-connection)
```bash
openclaw devices list
openclaw devices approve <requestId>
```


## To run the agent from now on:
- use [README.run.md](./README.run.md) for normal day-to-day usage
- if this agent needs Google account access, complete [README.google.md](./README.google.md) before day-to-day usage

---

## One off commands in cli
For one-off commands without bashing into a terminal session, replace openclaw with `docker compose run --rm --entrypoint openclaw openclaw-gateway-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
# OR
docker compose run --rm --entrypoint openclaw openclaw-gateway-cli devices list
```
