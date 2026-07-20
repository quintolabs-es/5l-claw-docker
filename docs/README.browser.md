# Browser Tool

This runbook is for OpenClaw instances created from this Docker template.

Use this when you want the agent to use OpenClaw's built-in `browser` tool. 
The tool works against the `Chromium` runtime that is already installed in the Docker image where the agent runs.

## Enable Browser In OpenClaw

Open `openclaw-standalone-cli`.

```bash
openclaw config set browser.enabled true
openclaw config set browser.headless true
openclaw config set plugins.entries.browser.enabled true
```

## Check plugins.allow

Inside `openclaw-standalone-cli`:

```bash
openclaw config get plugins.allow
```

If it returns nothing, leave it as is.

If it returns a list, add `browser` to that list.

Example:

```bash
openclaw config set plugins.allow '["telegram","discord","browser"]' --strict-json
```

## Check tools.alsoAllow

Inside `openclaw-standalone-cli`:

```bash
openclaw config get tools.alsoAllow
```

If it returns nothing, set it to:

```bash
openclaw config set tools.alsoAllow '["browser"]' --strict-json
```

If it returns a list, add `browser` to that list.

Example:

```bash
openclaw config set tools.alsoAllow '["web_search","browser"]' --strict-json
```

## Configure Chromium

Inside `openclaw-standalone-cli`:

```bash
openclaw config set browser.noSandbox true
openclaw config set browser.extraArgs '["--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36","--lang=es-ES","--window-size=1440,1000"]' --strict-json
```

## Restart The Gateway

Browser config changes require a gateway restart.

```bash
docker compose restart openclaw-gateway
### in qnap
docker-compose -f docker-compose-qnap.yml restart openclaw-gateway
```

## Verify It Works

Open `openclaw-gateway-cli`.

```bash
openclaw browser doctor
openclaw browser status
```

If `doctor` succeeds, the gateway can see and manage the browser runtime.
