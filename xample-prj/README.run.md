# OpenClaw Runbook

For first-time setup, use [README.onboard.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.onboard.md).

## Start Gateway

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

The `OPENCLAW_GATEWAY_TOKEN` is the token clients must present to connect to the gateway.

## Logs

```bash
docker compose logs -f openclaw-gateway
```

## Run CLI

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint bash openclaw-cli
```

## Gateway Status

```bash
openclaw gateway status --url ws://127.0.0.1:18789 --token "$OPENCLAW_GATEWAY_TOKEN"

# or one-off command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```

## Doctor

```bash
openclaw doctor

# or one-off command
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli doctor
```

## Open Control UI

```text
http://localhost:18789/
```

## State On Host

```bash
ls -la ./openclaw-data/.openclaw
```

## Stop

```bash
docker compose down
```
