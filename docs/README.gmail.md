# Gmail Access

This runbook is for OpenClaw instances created from this Docker template.

In this project:

- `gog` runs inside the Docker image, not on the host.
- `gog` config and secret state persist on the host under `./.secrets/gogcli/.config/`.
- Inside the containers, that path is mounted at `/home/node/.config/gogcli/`.
- `./.secrets/gogcli/.config/` contains secrets. Do not publish it.

## Create Google OAuth Desktop Credentials

Use Google Cloud `https://cloud.google.com`:

- Enable the Gmail API.
- Configure the OAuth consent screen.
- If the app is still in `Testing`, add your Gmail account as a test user.
- Create an OAuth client of type `Desktop app`.
  * Clients/Create new client/Desktop app
- Download the client JSON.

References:

- [gog quickstart](https://gogcli.sh/)
- [Gmail API quickstart](https://developers.google.com/workspace/gmail/api/quickstart/go)

## Stage The Client JSON In This Repo

```bash
cp <path-to-downloaded-client-json> ./.secrets/gogcli/.config/client_secret.json
```

The onboarding container does not see your host `~/Downloads`, so place the file in the mounted repo-local secret path first.

## First-Time Authorization

Export the runtime variables in the same shell you use for `docker compose`:

`GOG_KEYRING_PASSWORD` is a local encryption password for `gog`'s file keyring. Use the same value each time this agent instance is started, or `gog` will not be able to read the tokens it already stored and the account will need to re-authorized.

```bash
export GOG_KEYRING_PASSWORD='<strong-password>'
export GOG_ACCOUNT='<you@gmail.com>'
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --no-deps openclaw-onboard
```

Inside the container:

```bash
gog auth keyring file
gog auth credentials /home/node/.config/gogcli/client_secret.json
gog auth add <you@gmail.com> --services gmail --gmail-scope readonly --manual
```

`--manual` is the correct OAuth flow for this Docker setup:

- `gog` prints an auth URL.
- Open that URL in a local browser.
- Approve access.
- Copy the full redirect URL from the browser address bar.
- Paste that full redirect URL back into the container prompt.

If this agent needs Gmail write access later:

```bash
gog auth add <you@gmail.com> --services gmail --gmail-scope full --force-consent --manual
```

If this agent later needs other Google services as well:

```bash
gog auth add <you@gmail.com> --services gmail,drive,docs,sheets --force-consent --manual
```

## Start The Gateway With Gmail Access

`docker-compose.yml` passes `GOG_KEYRING_PASSWORD` and `GOG_ACCOUNT` from your host shell into `openclaw-onboard`, `openclaw-gateway`, and `openclaw-cli`.

Export them before you start the gateway:

```bash
export GOG_KEYRING_PASSWORD='<strong-password>'
export GOG_ACCOUNT='<you@gmail.com>'
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

## Verify It Works

```bash
export GOG_KEYRING_PASSWORD='<strong-password>'
export GOG_ACCOUNT='<you@gmail.com>'
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint bash openclaw-cli -lc "gog auth list --check && gog gmail search 'is:unread newer_than:7d' --max 10 --json"
```

The search command should return JSON from your mailbox. If the command prompts for a keyring password or fails to find the account, the container did not receive the expected environment variables.

## Troubleshooting

- `gog: command not found`
  Rebuild the image with `docker compose build`.
- `gog` keeps prompting for a keyring password
  Export `GOG_KEYRING_PASSWORD` in the shell before `docker compose up` or `docker compose run`.
- The OpenClaw Gmail skill does not load
  Make sure `gog` is on `PATH` inside the container and check `./.openclaw/openclaw.json` after onboarding. If `skills.allowBundled` is set, it must include `gog`.
- You need to inspect where `gog` is storing state
  Run `gog auth keyring`. It prints the selected backend and the resolved config path.
