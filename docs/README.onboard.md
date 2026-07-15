# OpenClaw Onboard
## Build

```bash
cd claw-agent
### in qnap
cd claw-agent
docker compose build
### in qnap
mkdir -p .openclaw/_secrets
touch .openclaw/_secrets/.env
docker-compose -f docker-compose-qnap.yml build
```

## Onboard
### Go through onboard, in Standalone CLI
```bash

# open a shell in the standalone CLI container to run onboard
docker compose run --rm --no-deps openclaw-standalone-cli
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm --no-deps openclaw-standalone-cli

# run Onboard and go through the setup. Make sure you:
### => go for quick start
### => do not configure the channel. you'll be sent to specific instructions later for Telegram
### => anything your are not sure, skip
### => do NOT hatch in terminal at the end.
openclaw onboard --mode local --no-install-daemon
### in qnap
openclaw onboard --mode local --no-install-daemon

# complete onboard for Docker and initialize the local .openclaw git repo
## `--gateway-token` is required. Generate a safe token and use it. It is set for both the gateway and the local CLI configs, so the gateway requires it and the local CLI commands already use it to auth against the gateway.
## optionally pass one GitHub remote mode:
##   --github-remote-url-new-workspace      when the target repo is empty/new and will become this agent's future workspace repo
##   --github-remote-url-existing-workspace when the target repo already contains the workspace to recover, the current workspace gets overwritten, and that repo should remain the future push target
## git name and email are optional and have a default value set
bash _scripts/complete-onboard.sh --gateway-token <openclaw-gateway-token> --github-remote-url-new-workspace <https://github.com/owner/repo> --git-name <"name-for-git-commits"> --git-email <email-for-git-commits>
### in qnap
bash _scripts/complete-onboard.sh --gateway-token <openclaw-gateway-token> --github-remote-url-new-workspace <https://github.com/owner/repo> --git-name <"name-for-git-commits"> --git-email <email-for-git-commits>
# OR
bash _scripts/complete-onboard.sh --gateway-token <openclaw-gateway-token> --github-remote-url-existing-workspace <https://github.com/owner/repo> --git-name <"name-for-git-commits"> --git-email <email-for-git-commits>
### in qnap
bash _scripts/complete-onboard.sh --gateway-token <openclaw-gateway-token> --github-remote-url-existing-workspace <https://github.com/owner/repo> --git-name <"name-for-git-commits"> --git-email <email-for-git-commits>
```

### Complete github authentication setup
If either GitHub remote flag is passed, the complete-onboard script creates or reuses a dedicated OpenClaw SSH key under `./.openclaw/_secrets/git/.ssh/`, prints the exact public key host path, and mounts that key as `~/.ssh` in the Docker containers that need Git access.

Add it in GitHub as a deploy key with write access for the target repo:
- Open the target GitHub repository.
- Go to `Settings`.
- Go to `Deploy keys`.
- Click `Add deploy key`.
- Paste the contents of the public key path printed by the script.
- Enable write access.
- Save.

If you used `--github-remote-url-new-workspace`, the script tests GitHub auth first and then pushes the initial workspace commit automatically.

If you used `--github-remote-url-existing-workspace`, the script tests GitHub auth first, fetches and attaches that repo during onboarding, and that same repo remains the future push target for workspace backups.

## Initialize Agent Workspace And State
These two recovery steps are optional and disjoint. Use either one or both. The recommended commands below overwrite the local targets; they do not merge with the local contents.

To do both recoveries, recover state first and initialize workspace second so the workspace wins last.

### Optional: Recover State
Use this to restore the non-workspace durable state from a prepared local `.openclaw` folder. This overwrites whatever currently exists in the local state paths and does not preserve the local copies.

Download the backup archive from Drive and place it at `/tmp/openclaw/state-backup.tar.gz`.

```bash
mkdir -p /tmp/openclaw/state
### in qnap
mkdir -p /tmp/openclaw/state
tar -xzf /tmp/openclaw/state-backup.tar.gz -C /tmp/openclaw/state
### in qnap
tar -xzf /tmp/openclaw/state-backup.tar.gz -C /tmp/openclaw/state
cd <agent-folder>
### in qnap
cd <agent-folder>
bash .openclaw/_scripts/restore-state.sh /tmp/openclaw/state/.openclaw
### in qnap
bash .openclaw/_scripts/restore-state.sh /tmp/openclaw/state/.openclaw
```

### Optional: Recover Workspace
Use this if you want to restore the agent workspace from a local prepared `.openclaw` folder. This overwrites the local `workspace/` and local `.gitignore` inside `/.openclaw`.

If the same GitHub repo should remain the future push target, do not use this path. Instead, use `--github-remote-url-existing-workspace` in `complete-onboard.sh`.

```bash
# clone the workspace locally
rm -rf /tmp/openclaw/workspace-source
### in qnap
rm -rf /tmp/openclaw/workspace-source
git clone https://www.github.com/remote/repo/to/recover /tmp/openclaw/workspace-source/.openclaw
### in qnap
git clone https://www.github.com/remote/repo/to/recover /tmp/openclaw/workspace-source/.openclaw

# initialize current agent with the cloned workspace
cd <agent-folder>
### in qnap
cd <agent-folder>
bash .openclaw/_scripts/initialize-workspace.sh /tmp/openclaw/workspace-source/.openclaw
### in qnap
bash .openclaw/_scripts/initialize-workspace.sh /tmp/openclaw/workspace-source/.openclaw
```

## Start the Gateway
**Basic onboarding is complete**, now run the gateway.

```bash
docker compose up -d openclaw-gateway
### in qnap
docker-compose -f docker-compose-qnap.yml up -d openclaw-gateway
```

This Docker setup does not install an OpenClaw host daemon. `openclaw onboard --mode local --no-install-daemon` keeps OpenClaw itself out of system startup, and Docker is the process supervisor instead.

`openclaw-gateway` uses Docker Compose `restart: unless-stopped`, so after you start it once with `docker compose up -d openclaw-gateway`, Docker starts it again automatically after a Raspberry Pi reboot as long as the container was not manually stopped or removed.

If you do not want automatic startup after reboot, stop it explicitly:

```bash
docker compose stop openclaw-gateway
### in qnap
docker-compose -f docker-compose-qnap.yml stop openclaw-gateway
```

#### Test gateway CLI
To run gateway CLI commands, run the gateway CLI container and bash into it. This tests connectivity between `openclaw-gateway-cli` and the running gateway.
```bash
docker compose run --rm openclaw-gateway-cli
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm openclaw-gateway-cli
# test it 
openclaw devices list
### in qnap
openclaw devices list
```


## Setup Control UI (paring)
Open gateway cli and run dashboard
```bash
docker compose run --rm openclaw-gateway-cli
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm openclaw-gateway-cli
openclaw dashboard
### in qnap
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

#### On first time open Control UI: Device pairing required
[Official doc](https://docs.openclaw.ai/web/control-ui#device-pairing-first-connection)
```bash
openclaw devices list
### in qnap
openclaw devices list
openclaw devices approve <requestId>
### in qnap
openclaw devices approve <requestId>
```

## Additional optional setup

### Telegram channel
Optional post-onboard setup.

If this agent should be reachable through Telegram, complete [README.telegram.md](./README.telegram.md) before using Telegram-based heartbeat or normal chat.

### Google Access
Optional post-onboard setup.

The agent can access Google services such as Gmail, Calendar, and Drive through the `gog` CLI skill. If needed, copy `./.openclaw/_secrets/.env.example` to `./.openclaw/_secrets/.env`, set `GOG_ACCOUNT` and `GOG_KEYRING_PASSWORD`, and then complete [README.google.md](./README.google.md).

### Set Hearbeat and heartbeat response channel
By default hearbit runs every 30m, executes `HEARTBEAT.md` prompt and response (if any) is sent to last channel.
Check `https://docs.openclaw.ai/gateway/heartbeat`.

```bash
openclaw config set agents.defaults.heartbeat.every "30m"
### in qnap
openclaw config set agents.defaults.heartbeat.every "30m"
openclaw config set agents.defaults.heartbeat.target "telegram"
### in qnap
openclaw config set agents.defaults.heartbeat.target "telegram"
openclaw config set agents.defaults.heartbeat.to "telegram"
### in qnap
openclaw config set agents.defaults.heartbeat.to "telegram"
openclaw config set agents.defaults.heartbeat.activeHours.start "07:00"
### in qnap
openclaw config set agents.defaults.heartbeat.activeHours.start "07:00"
openclaw config set agents.defaults.heartbeat.activeHours.end "23:59"
### in qnap
openclaw config set agents.defaults.heartbeat.activeHours.end "23:59"
openclaw config set agents.defaults.heartbeat.activeHours.timezone "Europe/Madrid"
### in qnap
openclaw config set agents.defaults.heartbeat.activeHours.timezone "Europe/Madrid"
```

The value `agents.defaults.heartbeat.target` specifies where to send the heartbeat response/result message, in case there is one.

### Others
Web search
```bash
openclaw configure --section web
### in qnap
openclaw configure --section web
```


## To run the agent from now on:
- use [README.run.md](./README.run.md) for normal day-to-day usage

---

## One off commands in cli
For one-off commands without bashing into a terminal session, replace openclaw with `docker compose run --rm --entrypoint openclaw openclaw-gateway-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
### in qnap
openclaw devices list
# OR
docker compose run --rm --entrypoint openclaw openclaw-gateway-cli devices list
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm --entrypoint openclaw openclaw-gateway-cli devices list
```
