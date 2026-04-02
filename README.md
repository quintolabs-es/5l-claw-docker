# OpenClaw Docker Packaging

This repo packages OpenClaw in Docker using the official installer command from the OpenClaw website.

The container is disposable. Durable OpenClaw state lives in a local project folder so you can rebuild the image and recover the same agent state.

The image build disables installer onboarding with `OPENCLAW_NO_ONBOARD=1` so `docker build` can complete without an interactive TTY. In this Docker setup, `openclaw onboard --install-daemon` is not used; Docker Compose is the process supervisor and starts the gateway with `openclaw gateway run`.

## Why This Exists

Unlike the official Docker setup, which writes config and workspace on the host under `~/.openclaw/` and `~/.openclaw/workspace`, this packaging keeps all OpenClaw state inside this project folder so the environment stays repo-local and can be versioned.

## Install
```bash
mkdir -p claw-agent
cd claw-agent
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/init-clow-docker.sh?skip-cache=$(date +%s)" | bash
```

The init script creates the Docker packaging files in the current folder, so run it from the directory where you want this OpenClaw instance to live.

After install, continue with onboarding in [README.claw-onboard.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.claw-onboard.md).

## Runtime

- Persisted state:
  `./openclaw-data/.openclaw`
- Main config:
  `./openclaw-data/.openclaw/openclaw.json`
- Human-edited memory/workspace:
  `./openclaw-data/.openclaw/workspace/`
- Services:
  * `openclaw-onboard` is used for pre-start setup commands. 
  * `openclaw-gateway` runs continuously. 
  * `openclaw-cli` runs on demand after the gateway is up and shares the gateway network.

## Gateway

- Container port:
  `18789`
- Host port:
  `18789 -> 18789`
- WebSocket gateway:
  `ws://localhost:18789/`
- HTTP surface:
  `http://localhost:18789/`

The gateway serves the WebSocket API and the browser Control UI on the same port. The Control UI is the small website bundled with OpenClaw. Open it at `http://localhost:18789/` to operate the local gateway.

Control UI origin policy is configured in `./openclaw-data/.openclaw/openclaw.json`. This setup allowlists only `http://localhost:18789`.

## Runbooks

See [README.claw-onboard.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.claw-onboard.md) for first-time setup.
See [README.claw-run.md](/Users/luismesa/Documents/src/quintolabs/5l-claw-docker/README.claw-run.md) for normal run commands.
