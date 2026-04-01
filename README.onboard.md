# OpenClaw Onboard

## Build

```bash
docker compose build
```

## Onboard
Use `openclaw-onboard` for `onboard` and initial config, since `openclaw-cli` is attached to the running gateway network, so it cannot be used for pre-start setup. 

```bash
# open a shell in the onboard container
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard

# run Onboard
openclaw onboard --mode local --no-install-daemon

# configure Gateway For Docker
openclaw config set gateway.mode local
openclaw config set gateway.bind lan
openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json

## exit the container terminal
```

Back on the host terminal
```bash
# delete useless git repo created by openclaw during onboarding
rm -rf ./openclaw-data/.openclaw/workspace/.git
```

In general, for one-off commands without bashing into a terminal session:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard <openclaw command>
# e.g.
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard config set gateway.mode local
```


## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway

# check gateway status 
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```
_It's expected that `systemd` check fails, because it's not used in docker._

## Run CLI
To run cli commands, run the cli container and bash into it
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli
# test it 
openclaw --help
```

For one-off commands without bashing into a terminal session:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli <openclaw command args>

# e.g.: openclaw devices list:
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli devices list
```


## Open Control UI
Run in CLI
```bash
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

### Device pairing for first connection
[Official doc](https://docs.openclaw.ai/web/control-ui#device-pairing-first-connection)
```bash
openclaw devices list
openclaw devices approve <requestId>
```

## One off commands
For one-off commands without bashing into a terminal session, replace openclaw with `OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
# OR
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli devices list
```