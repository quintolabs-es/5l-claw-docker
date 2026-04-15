# Google Access

This runbook is for OpenClaw instances created from this Docker template.

In this project:

- `gog` runs inside the Docker image, not on the host.
- `gog` config and secret state persist on the host under `./.openclaw/_secrets/gogcli/.config/`.
- Inside the containers, that path is mounted at `/home/node/.config/gogcli/`.
- `./.openclaw/_secrets/` contains secrets and is intentionally included in the `.openclaw` backup repo. Use a private remote.

## Create Google OAuth Desktop Credentials in google cloud

Use Google Cloud: `https://console.cloud.google.com/`.

1. Create the Google Cloud project for this agent.
2. Enable the required APIs.
   - Open [Gmail API](https://console.cloud.google.com/apis/library/gmail.googleapis.com)
   - Click `Enable`
   - Open [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com)
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
cp <path-to-downloaded-client-json> ./.openclaw/_secrets/gogcli/.config/client_secret.json
```

## Setup Gmail Access

Copy `./.openclaw/_secrets/.env.example` to `./.openclaw/_secrets/.env` and set these values.
```dotenv
GOG_KEYRING_PASSWORD=<strong-password>
GOG_ACCOUNT=<you@gmail.com>
```

`GOG_KEYRING_PASSWORD` is a local encryption password for `gog`'s file keyring. Use the same value each time this agent instance is started, or `gog` will not be able to read the tokens it already stored and the account will need to be re-authorized.

Open a shell in the standalone CLI container:

```bash
docker compose run --rm --no-deps openclaw-standalone-cli
```

Inside the standalone CLI container:

```bash
gog auth keyring file
gog auth credentials /home/node/.config/gogcli/client_secret.json
gog auth add <you@gmail.com> --services gmail,drive --gmail-scope readonly --manual
```

If you later add services or change the Gmail scope, rerun `gog auth add ...` with `--force-consent`.
```bash
gog auth add <you@gmail.com> --services gmail,drive --gmail-scope readonly --manual --force-consent
```

Service options for `--services`:
- `gmail`
- `drive`
- `docs`
- `sheets`

Gmail scope options for `--gmail-scope`:
- `readonly`
- `full`


`--manual` is the correct OAuth flow for this Docker setup:

- `gog` prints an auth URL.
- Open that URL in a local browser.
- Approve access.
- Copy the full redirect URL from the browser address bar.
- Paste that full redirect URL back into the container prompt.

If the gateway was already running when `.env` was changed, restart it after setup:

```bash
docker compose restart openclaw-gateway
```

## Verify It Works
Open `openclaw-standalone-cli`.

To verify gmail, run
```bash
gog auth list --check && gog gmail search 'is:unread newer_than:7d' --max 10 --json
```

The search command should return JSON from your mailbox. If the command prompts for a keyring password or fails to find the account, check the `GOG_KEYRING_PASSWORD` and `GOG_ACCOUNT` values in `./.openclaw/_secrets/.env`.

To verify drive, run
```bash
gog auth list --check && gog drive ls --max 10 --json
```

The Drive command should return JSON metadata for files visible in your Google Drive account.

## Troubleshooting

- `gog: command not found`
  Rebuild the image with `docker compose build`.
- `gog` keeps prompting for a keyring password
  Check the `GOG_KEYRING_PASSWORD` value in `./.openclaw/_secrets/.env`.
- The OpenClaw Gmail skill does not load
  Make sure `gog` is on `PATH` inside the container and check `./.openclaw/openclaw.json` after onboarding. If `skills.allowBundled` is set, it must include `gog`.
- You need to inspect where `gog` is storing state
  Run `gog auth keyring`. It prints the selected backend and the resolved config path.
