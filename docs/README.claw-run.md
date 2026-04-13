# OpenClaw Runbook

For first-time setup, use [README.claw-onboard.md](./README.claw-onboard.md).

## Google Access
If this agent uses Gmail or other Google account access through `gog`, also use [README.gmail.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/docs/README.gmail.md).

## Start Gateway
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

`GOG_ACCOUNT` and `GOG_KEYRING_PASSWORD` are configured in [docker-compose.yml](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/docker-compose.yml) when this agent needs Google account access.

## Open Control UI
Browse to `http://localhost:18789/`

Or run in CLI
```bash
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

## Run CLI
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli
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
For one-off commands without bashing into a terminal session, replace openclaw with `OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
# OR
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli devices list
```
