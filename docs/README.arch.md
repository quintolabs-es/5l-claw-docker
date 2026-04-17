# Architecture

## Runtime

- Persisted state:
  `./.openclaw`
- Main config:
  `./.openclaw/openclaw.json`
- Human-edited memory/workspace:
  `./.openclaw/workspace/`
- Services:
  * `openclaw-standalone-cli` is used for onboarding, backup, restore, and other local state commands that do not require the gateway.
  * `openclaw-gateway` runs continuously.
  * `openclaw-gateway-cli` runs on demand after the gateway is up and shares the gateway network for commands that talk to the running gateway.

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

Control UI origin policy is configured in `./.openclaw/openclaw.json`. This setup allowlists only `http://localhost:18789`.
