```md
# AGENTS.project.md

## Repo

- Workspace repo: `/Users/luismesa/Documents/src/quintolabs/5l-claw-docker`
- Read and follow `AGENTS.md` at repo root before doing work.
- Important repo rule: analyze first, and only edit after explicit `PROCEED`.

## Goal

Package OpenClaw in Docker with repo-local state and a workflow close to official OpenClaw usage, but without spreading workspace/config across the host under `~/.openclaw`.

Core motivation:
- Official Docker setup writes config/workspace under `~/.openclaw/` and `~/.openclaw/workspace`.
- This project keeps OpenClaw state inside the project folder so the environment stays repo-local and can be versioned.

## Current Docker design

`docker-compose.yml` has 3 services:

1. `openclaw-onboard`
- Used for pre-start onboarding and config only
- Shares the same image and state mount as gateway
- No `network_mode` dependency
- Intended default behavior: open a shell

2. `openclaw-gateway`
- Long-running service
- Runs:
  `openclaw gateway run --bind lan --port 18789`
- Publishes host port `18789`

3. `openclaw-cli`
- Used for post-start CLI only
- Shares gateway namespace with:
  `network_mode: "service:openclaw-gateway"`
- Intended default behavior: open a shell
- One-off CLI commands should use `--entrypoint openclaw`

## Current service UX decision

For both `openclaw-onboard` and `openclaw-cli`:

- `entrypoint` should be `["bash"]`
- Do not use `command: ["--help"]`
- `stdin_open: true` and `tty: true` should be enabled
- Opening a shell should be the natural/default command
- One-off commands should override the entrypoint with `--entrypoint openclaw`

Desired command examples:

Open onboarding shell:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard
```

One-off onboarding command:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard onboard --mode local --no-install-daemon
```

Open CLI shell:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli
```

One-off CLI command:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli gateway status --url ws://127.0.0.1:18789 --token "$OPENCLAW_GATEWAY_TOKEN"
```

## Persistent state mapping

Host:
- `./openclaw-data/.openclaw`

Container:
- `/home/node/.openclaw`

Important:
- `init-clow-docker.sh` must NOT create `openclaw-data/.openclaw`
- Let Docker/OpenClaw create/use the state path later
- There was a Docker Desktop bind-mount failure discussion around an existing `openclaw-data/.openclaw` path; the exact daemon-side cause was not proven from repo files alone
- What is known: the failing component is Docker daemon bind-mount setup, not `bash`, not `openclaw`, not the Dockerfile

## Current onboarding workflow

Build:
```bash
docker compose build
```

Open onboarding shell:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard
```

Inside onboarding shell:
```bash
openclaw onboard --mode local --no-install-daemon
openclaw config set gateway.mode local
openclaw config set gateway.bind lan
openclaw config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json
```

Back on host, after onboarding:
```bash
rm -rf ./openclaw-data/.openclaw/workspace/.git
```

One-off onboarding commands:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard onboard --mode local --no-install-daemon
rm -rf ./openclaw-data/.openclaw/workspace/.git
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard config set gateway.mode local
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard config set gateway.bind lan
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps --entrypoint openclaw openclaw-onboard config set gateway.controlUi.allowedOrigins '["http://localhost:18789"]' --strict-json
```

Important established fact:
- `openclaw config set ...` commands are local config-file commands; they do not require the gateway to already be running

## Current runtime workflow

Start gateway:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

Open CLI shell:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli
```

Inside CLI shell:
```bash
openclaw --help
openclaw gateway status --url ws://127.0.0.1:18789 --token "$OPENCLAW_GATEWAY_TOKEN"
openclaw doctor
```

One-off status:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli gateway status --url ws://127.0.0.1:18789 --token openclaw-gateway-default-token
```

One-off doctor:
```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint openclaw openclaw-cli doctor
```

Control UI:
```text
http://localhost:18789/
```

Logs:
```bash
docker compose logs -f openclaw-gateway
```

## Important behavior/status already observed

OpenClaw status was previously basically working:
- Gateway reachable
- RPC probe ok
- Telegram ON / OK

Expected in Docker:
- `systemd` warnings are expected and not considered functional failures

## Documentation / naming decisions

Checked-in repo docs:
- Keep `README.md` as the main repo README

Generated-by-init docs:
- `README.claw.md`
- `README.claw-onboard.md`
- `README.claw-run.md`

Current user decision:
- The init script should create a placeholder local `README.md`
- The init script should download the actual package docs from the remote repo:
  - remote `README.md` -> local `README.claw.md`
  - remote `README.claw-onboard.md` -> local `README.claw-onboard.md`
  - remote `README.claw-run.md` -> local `README.claw-run.md`

Placeholder `README.md` content should be minimal, e.g.:
```md
# README

Document this claw instance here.
```

## Init script desired behavior

`init-clow-docker.sh` should:
1. Use `ROOT_DIR="${PWD}"`
2. Write:
   - `docker-compose.yml`
   - `Dockerfile`
   - placeholder `README.md`
3. Download from raw GitHub:
   - `README.md` as `README.claw.md`
   - `README.claw-onboard.md` as `README.claw-onboard.md`
   - `README.claw-run.md` as `README.claw-run.md`
4. Not create `openclaw-data/.openclaw`
5. Print a short handoff telling the user to read `README.claw-onboard.md`

Important:
- Use raw GitHub URLs, not `github.com/.../blob/...`
- Example raw base:
  `https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main`
- Cache-busting for install command can use:
  `?ts=$(date +%s)`

## Install command convention

Preferred init command:
```bash
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/init-clow-docker.sh?ts=$(date +%s)" | bash
```

Why:
- avoids stale cached script content

## Files that matter most

- `Dockerfile`
- `docker-compose.yml`
- `README.md`
- `README.claw.md`
- `README.claw-onboard.md`
- `README.claw-run.md`
- `init-clow-docker.sh`

## Constraints / preferences from user

- Keep repo-local state; do not switch to machine-wide `~/.openclaw`
- Keep onboarding UX close to official docs
- Use a dedicated onboarding container/service
- `openclaw-cli` is intentionally post-start only
- Prefer minimal churn and practical docs
- If updating generated docs, keep `init-clow-docker.sh` aligned with them
- If something is not provable from files alone, say so directly instead of guessing

## Known environment caveat

There were intermittent write-permission issues in this workspace from this session:
- some repo file reads/writes/renames started failing with `Operation not permitted`
- because of that, some intended changes may have been discussed but not actually applied
- future work should re-read the actual files from disk before assuming generator/docs are already aligned
```