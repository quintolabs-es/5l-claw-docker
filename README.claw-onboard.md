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

# configure Gateway For Docker
openclaw config set gateway.mode local
openclaw config set gateway.bind lan
openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json

## exit the container terminal
exit
```

Back on the host terminal
```bash
# delete useless git repo created by openclaw during onboarding
rm -rf ./openclaw-data/.openclaw/workspace/.git
```

## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway

# check gateway status 
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```
_It's expected that `systemd` check fails, because it's not used in docker._

After onboarding is complete, use [README.claw-run.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.claw-run.md) for normal day-to-day usage.

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
