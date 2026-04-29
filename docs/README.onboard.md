# OpenClaw Onboard
## Build

```bash
cd claw-agent
docker compose build
```

## Onboard
Use `openclaw-standalone-cli` for `onboard` and initial config. It does not require the gateway to be running. Use `openclaw-gateway-cli` only for commands that talk to the running gateway.

```bash
# open a shell in the standalone CLI container to run onboard
docker compose run --rm --no-deps openclaw-standalone-cli

# run Onboard and go through the setup.
openclaw onboard --mode local --no-install-daemon

# complete onboard for Docker and initialize the local .openclaw git repo
## `--gateway-token` is required. It is set for both the gateway and the local CLI configs, so the gateway requires it and the local CLI commands already use it to auth against the gateway.
## optionally pass one GitHub remote mode:
##   --github-remote-url-new-workspace      when the target repo is empty/new and will become this agent's future workspace repo
##   --github-remote-url-existing-workspace when the target repo already contains the workspace to recover (current workspace gets OVEWRITTEN) and should remain the future push target
## git name and email are optional and have a default value set
bash _scripts/complete-onboard.sh --gateway-token <openclaw-gateway-token> --github-remote-url-new-workspace <https://github.com/owner/repo> --git-name <"name-for-git-commits"> --git-email <email-for-git-commits>
# OR
bash _scripts/complete-onboard.sh --gateway-token <openclaw-gateway-token> --github-remote-url-existing-workspace <https://github.com/owner/repo> --git-name <"name-for-git-commits"> --git-email <email-for-git-commits>
```

### Complete github authentication setup
If either GitHub remote flag is passed, the complete-onboard script creates SSH files in `./.openclaw/_secrets/git/.ssh/` on the host and mounts them as `~/.ssh` in the Docker containers that need Git access.

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

If you used `--github-remote-url-new-workspace`, **then back to the standalone CLI container**, verify push works:
```bash
git push -u origin HEAD
```

If you used `--github-remote-url-existing-workspace`, the script uses that same repo to fetch and attach the current agent workspace during onboarding, and that repo remains the future push target for workspace backups.

## Initialize Agent Workspace And State
These two recovery steps are optional and disjoint. Use either one or both. The recommended commands below overwrite the local targets; they do not merge with the local contents.

To do both recoveries, recover state first and initialize workspace second so the workspace wins last.

### Optional: Recover State
Use this to restore the non-workspace durable state from a prepared local `.openclaw` folder. This overwrites whatever currently exists in the local state paths and does not preserve the local copies.

Download the backup archive from Drive and place it at `/tmp/openclaw/state-backup.tar.gz`.

```bash
mkdir -p /tmp/openclaw/state
tar -xzf /tmp/openclaw/state-backup.tar.gz -C /tmp/openclaw/state
cd <agent-folder>
bash .openclaw/_scripts/restore-state.sh /tmp/openclaw/state/.openclaw
```

### Optional: Recover Workspace
Use this if you want to restore the agent workspace from a local prepared `.openclaw` folder. This overwrites the local `workspace/` and local `.gitignore` inside `/.openclaw`.

If the same GitHub repo should remain the future push target, do not use this path. Instead, use `--github-remote-url-existing-workspace` in `complete-onboard.sh`.

```bash
# clone the workspace locally
rm -rf /tmp/openclaw/workspace-source
git clone https://www.github.com/remote/repo/to/recover /tmp/openclaw/workspace-source/.openclaw

# initialize current agent with the cloned workspace
cd <agent-folder>
bash .openclaw/_scripts/initialize-workspace.sh /tmp/openclaw/workspace-source/.openclaw
```

## Start the Gateway
**Basic onboarding is complete**, run the gateway.

```bash
docker compose up -d openclaw-gateway
```

Check gateway status from the gateway cli:
```bash
docker compose run --rm openclaw-gateway-cli
openclaw gateway status
```
_It's expected that `systemd` check fails, because it's not used in docker._

#### Test gateway CLI
To run gateway CLI commands, run the gateway CLI container and bash into it. This tests connectivity between `openclaw-gateway-cli` and the running gateway.
```bash
docker compose run --rm openclaw-gateway-cli
# test it 
openclaw devices list
```

## Setup Control UI (paring)
Open gateway cli and run dashboard
```bash
docker compose run --rm openclaw-gateway-cli
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

#### On first time open Control UI: Device pairing required
[Official doc](https://docs.openclaw.ai/web/control-ui#device-pairing-first-connection)
```bash
openclaw devices list
openclaw devices approve <requestId>
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
