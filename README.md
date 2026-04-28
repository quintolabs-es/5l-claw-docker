# OpenClaw Docker Packaging

This repo packages OpenClaw in Docker using the official installer command from the OpenClaw website.

The container is disposable. Durable OpenClaw state lives in a local project folder so you can rebuild the image and recover the same agent state.

The image build disables installer onboarding with `OPENCLAW_NO_ONBOARD=1` so `docker build` can complete without an interactive TTY. In this Docker setup, `openclaw onboard --install-daemon` is not used; Docker Compose is the process supervisor and starts the gateway with `openclaw gateway run`.

## Why This Exists

Unlike the official Docker setup, which writes config and workspace on the host under `~/.openclaw/` and `~/.openclaw/workspace`, this packaging keeps all OpenClaw state inside this project folder so the environment stays repo-local and can be versioned.

## Init
```bash
mkdir claw-agent
cd claw-agent
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- init
# or specifing a port different than default
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- init --port 19001
```

The init script creates the Docker packaging files in the current folder, so run it from the directory where you want this OpenClaw instance to live.
Always use the latest script from the repo through `curl`, not a possibly outdated local copy.
`init` assumes the target folder is empty and fails if it already contains files.

After init, continue with onboarding in [docs/README.onboard.md](docs/README.onboard.md).

## Update
```bash
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- update
```

`update` is for an existing project. Always use the latest script from the repo through `curl`, not a possibly outdated local copy. It preserves the current port by default, keeps `README.md` if it already exists, keeps `./.openclaw/.gitignore` if it already exists, and leaves existing git/SSH setup in place. If the current port cannot be detected safely, pass `--port`.

`update` prompts for confirmation and then fully replaces these managed folders:

- `docs/`
- `scripts/`
- `./.openclaw/_scripts/`
- `./.openclaw/skills/backup-state-to-drive/`
- `./.openclaw/skills/backup-workspace-to-git/`

Files outside those folders are not touched. If you have files that must not be overwritten, keep them outside those managed folders, for example in a dedicated folder or at the project root.


## Runbooks

See [docs/README.onboard.md](docs/README.onboard.md) for first-time setup.
See [docs/README.run.md](docs/README.run.md) for normal run commands.
See [docs/README.google.md](docs/README.google.md) if this agent needs Google account access through `gog`.
See [docs/README.telegram.md](docs/README.telegram.md) if this agent should be reachable through Telegram.

See [docs/README.arch.md](docs/README.arch.md) for runtime and gateway architecture.
