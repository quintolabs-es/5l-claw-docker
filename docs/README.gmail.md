# Gmail Access

This runbook is for OpenClaw instances created from this Docker template.

In this project:

- `gog` runs inside the Docker image, not on the host.
- `gog` config and secret state persist on the host under `./.secrets/gogcli/.config/`.
- Inside the containers, that path is mounted at `/home/node/.config/gogcli/`.
- `./.secrets/gogcli/.config/` contains secrets. Do not publish it.

## Create Google OAuth Desktop Credentials

Use Google Cloud: `https://console.cloud.google.com/`.

1. Create the Google Cloud project for this agent.
2. Enable the Gmail API.
   - Open [Gmail API](https://console.cloud.google.com/apis/library/gmail.googleapis.com)
   - Click `Enable`
3. Configure Google Auth Platform.
   - Open [Google Auth Platform](https://console.cloud.google.com/auth)
   - If not configured yet, click `Get started`
4. Complete `Branding`.
   - Set `App name`
   - Set `User support email`
   - Set `Developer contact information`
5. Complete `Audience`.
   - For a personal Gmail account, use `External`.
   - If the app stays in `Testing`, add the same Gmail account as a `Test user`
6. Complete `Clients`.
   - Open [Clients](https://console.cloud.google.com/auth/clients)
   - Click `Create client`
   - Select `Desktop app`
   - Create the client
   - Download the OAuth client JSON


References:
- [gog quickstart](https://gogcli.sh/)
- [Gmail API quickstart](https://developers.google.com/workspace/gmail/api/quickstart/go)
- [Get started with the Google Auth Platform](https://support.google.com/cloud/answer/15544987?hl=en)
- [Manage OAuth Clients](https://support.google.com/cloud/answer/6158849?hl=en)
- [Submitting your app for verification](https://support.google.com/cloud/answer/13461325?hl=en)

## Stage The Client JSON In This Repo

```bash
cp <path-to-downloaded-client-json> ./.secrets/gogcli/.config/client_secret.json
```

## Setup Gmail Access

Copy `.env.example` to `.env` and set these values.
```dotenv
GOG_KEYRING_PASSWORD=<strong-password>
GOG_ACCOUNT=<you@gmail.com>
```

`GOG_KEYRING_PASSWORD` is a local encryption password for `gog`'s file keyring. Use the same value each time this agent instance is started, or `gog` will not be able to read the tokens it already stored and the account will need to be re-authorized.

Start the gateway:

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose up -d openclaw-gateway
```

Open a shell in the CLI container:

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm openclaw-cli
```

Inside the CLI container:

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

If the gateway was already running when `.env` was changed, restart it after setup:

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose restart openclaw-gateway
```

## Verify It Works

```bash
OPENCLAW_GATEWAY_TOKEN=openclaw-gateway-default-token docker compose run --rm --entrypoint bash openclaw-cli -lc "gog auth list --check && gog gmail search 'is:unread newer_than:7d' --max 10 --json"
```

The search command should return JSON from your mailbox. If the command prompts for a keyring password or fails to find the account, check the `GOG_KEYRING_PASSWORD` and `GOG_ACCOUNT` values in `.env`.

## Troubleshooting

- `gog: command not found`
  Rebuild the image with `docker compose build`.
- `gog` keeps prompting for a keyring password
  Check the `GOG_KEYRING_PASSWORD` value in `.env`.
- The OpenClaw Gmail skill does not load
  Make sure `gog` is on `PATH` inside the container and check `./.openclaw/openclaw.json` after onboarding. If `skills.allowBundled` is set, it must include `gog`.
- You need to inspect where `gog` is storing state
  Run `gog auth keyring`. It prints the selected backend and the resolved config path.
