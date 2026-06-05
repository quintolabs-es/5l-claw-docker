# OpenClaw Runbook

For first-time setup, use [README.onboard.md](./README.onboard.md).

## Start Gateway
```bash
docker compose up -d openclaw-gateway
```

## Open Control UI
Browse to `http://localhost:18789/`

Or run in CLI
```bash
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

## Run either gateway or standalone CLI
```bash
cd claw-agent

# Standalone CLI for onboarding, local state maintenance, backup, restore,
# and gog commands that do not require the gateway network namespace.
docker compose run --rm --no-deps openclaw-standalone-cli

# CLI that shares the gateway network namespace and is intended for commands
# that talk to the running gateway over 127.0.0.1.
docker compose run --rm openclaw-gateway-cli
```

## Useful Commands
### Commit and push the nested `.openclaw` repo **from the host** through the standalone CLI container:
```bash
bash ./scripts/git-commit-push-workspace-from-host.sh "<commit-message>"
```

## Doctor
```bash
<run-openclaw-cli>
openclaw doctor
```

## Logs
```bash
cd claw-agent
docker compose logs -f openclaw-gateway
```

## Stop
```bash
cd claw-agent
docker compose down
```

---

## One off commands
For one-off commands without bashing into a terminal session, replace openclaw with `docker compose run --rm --entrypoint openclaw openclaw-gateway-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list
# OR
docker compose run --rm --entrypoint openclaw openclaw-gateway-cli devices list
```
