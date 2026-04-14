# OpenClaw Runbook

For first-time setup, use [README.onboard.md](./README.onboard.md).

## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

## Open Control UI
Browse to `http://localhost:18789/`

Or run in CLI
```bash
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

## Run CLI
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-gateway-cli
```

## Doctor
```bash
openclaw doctor
```

## Logs
```bash
docker compose logs -f openclaw-gateway
```

## State On Host
```bash
ls -la ./.openclaw
```

## Stop
```bash
docker compose down
```

---

## One off commands
For one-off commands without bashing into a terminal session, replace openclaw with `OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-gateway-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
# OR
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-gateway-cli devices list
```
