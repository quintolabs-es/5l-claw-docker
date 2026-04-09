# OpenClaw Onboard



## Build

```bash
docker compose build
```

## Onboard
Use `openclaw-onboard` for `onboard` and initial config, since `openclaw-cli` is attached to the running gateway network, so it cannot be used for pre-start setup. 

```bash
# open a shell in the onboard container to run onbard command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard

# run Onboard and go through the setup
openclaw onboard --mode local --no-install-daemon

# complete onboard for Docker and initialize the durable state repo with remote origin
cd .openclaw
bash complete-onboard.sh --github-repo-url https://github.com/<owner>/<repo>

# also optional parameters 
--git-name: default "La Garra" 
--git-email default:"lagarra@quintolabs.es"

# OR just run with default params and local repo with no remote origin
bash complete-onboard.sh
```

If `--github-repo-url` was used, the complete-onboard script creates SSH files in `./.secrets/git/.ssh/` on the host and mounts them as `~/.ssh` in the Docker containers that may need Git access.

**Add the generated public key in GitHub** as a deploy key with write access for that private repo:
```bash
cat ./.secrets/git/.ssh/id_ed25519.pub
```

**Then back to the onboard container**, verify push works:
```bash
git push origin head
```



## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway

# check gateway status 
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```
_It's expected that `systemd` check fails, because it's not used in docker._

After onboarding is complete, use [README.claw-run.md](README.claw-run.md) for normal day-to-day usage.

## Test run CLI
To run cli commands, run the cli container and bash into it
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli
# test it 
openclaw --help
```

## Open Control UI
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

---

## One off commands in cli
For one-off commands without bashing into a terminal session, replace openclaw with `OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
# OR
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli devices list
```
