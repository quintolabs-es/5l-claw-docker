# OpenClaw Runbook

For first-time setup, use [README.onboard.md](./README.onboard.md).

## Start Gateway
```bash
docker compose up -d openclaw-gateway
### in qnap
docker-compose -f docker-compose-qnap.yml up -d openclaw-gateway
```

This repo does not install an OpenClaw host daemon. Docker is the process supervisor for the gateway container.

`openclaw-gateway` uses Docker Compose `restart: unless-stopped`, so once you start it with `docker compose up -d openclaw-gateway`, Docker brings it back automatically after a host reboot unless you stop or remove that container first.

## Open Control UI
Browse to `http://localhost:18789/`

Or, from `openclaw-gateway-cli`, run:
```bash
openclaw dashboard
```
Get tokenized url or plane url and add the gateway token where requested.

## Run gateway CLI or standalone CLI
```bash
cd claw-agent

# Standalone CLI for onboarding, local state maintenance, backup, restore,
# and gog commands that do not require the gateway network namespace.
docker compose run --rm --no-deps openclaw-standalone-cli
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm --no-deps openclaw-standalone-cli

# CLI that shares the gateway network namespace and is intended for commands
# that talk to the running gateway over 127.0.0.1.
docker compose run --rm openclaw-gateway-cli
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm openclaw-gateway-cli
```

## Open Terminal CLI
Open `openclaw-gateway-cli` and run:

```bash
openclaw tui

## Aliases that open the same terminal CLI:
openclaw chat
openclaw terminal

## Exit cleanly with 
/exit
```

## Useful Commands
### Commit and push the nested `.openclaw` repo **from the host** through the standalone CLI container:
```bash
bash ./scripts/git-commit-push-workspace-from-host.sh "<commit-message>"
```

## Doctor
```bash
cd claw-agent

docker compose run --rm --entrypoint openclaw openclaw-gateway-cli doctor
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm --entrypoint openclaw openclaw-gateway-cli doctor
```

## Logs
```bash
cd claw-agent

docker compose logs -f openclaw-gateway
### in qnap
docker-compose -f docker-compose-qnap.yml logs -f openclaw-gateway
```

## Stop
```bash
cd claw-agent

docker compose down
### in qnap
docker-compose -f docker-compose-qnap.yml down
```

`docker compose down` removes the gateway container, so there is nothing left for Docker to auto-start on the next reboot. Use `docker compose up -d openclaw-gateway` again when you want it back.

If you only want to keep the gateway stopped without removing the container, use:

```bash
cd claw-agent

docker compose stop openclaw-gateway
### in qnap
docker-compose -f docker-compose-qnap.yml stop openclaw-gateway
```

With `restart: unless-stopped`, a manually stopped gateway stays down across reboot until you start it again yourself.

---

## One off commands
For one-off commands without opening `openclaw-gateway-cli`, replace openclaw with `docker compose run --rm --entrypoint openclaw openclaw-gateway-cli`
```bash
# e.g.: openclaw devices list:
openclaw devices list

# OR
docker compose run --rm --entrypoint openclaw openclaw-gateway-cli devices list
### in qnap
docker-compose -f docker-compose-qnap.yml run --rm --entrypoint openclaw openclaw-gateway-cli devices list
```
