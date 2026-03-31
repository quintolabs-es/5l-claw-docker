# OpenClaw Onboard

## Build

```bash
docker compose build
```

## Onboard
Use `openclaw-onboard` for `onboard` and initial config, since `openclaw-cli` is attached to the running gateway network, so it cannot be used for pre-start setup. 

```bash
# run the gateway and bash into the terminal
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint bash openclaw-onboard

# run Onboard
openclaw onboard --mode local --no-install-daemon

## exit the container terminal
```

Back on the host terminal
```bash
# delete useless git repo created by openclaw during onboarding
rm -rf ./openclaw-data/.openclaw/workspace/.git

# configure Gateway For Docker from the host
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.mode local
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.bind lan
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json
```

OR alternatively, use one-off commands for all the above
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw onboard --mode local --no-install-daemon
rm -rf ./openclaw-data/.openclaw/workspace/.git
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.mode local
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.bind lan
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json
```


## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway

# bash into terminal and check Gateway Status
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint bash openclaw-cli
openclaw gateway status --url ws://127.0.0.1:18789 --token "$OPENCLAW_GATEWAY_TOKEN"

# OR one-off command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```

## Open Control UI

```text
http://localhost:18789/
```

## Logs

```bash
docker compose logs -f openclaw-gateway
```
