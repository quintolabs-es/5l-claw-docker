# Backup And Restore

## Backup Workspace To Git
```bash
docker compose run --rm --no-deps --entrypoint bash openclaw-standalone-cli -lc 'cd /home/node/.openclaw && bash skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh'
```

This script stages only `workspace/` in the nested `.openclaw` git repo, creates a commit if there are changes, and pushes when `origin` exists.

## Backup Agent State To Drive
```bash
docker compose run --rm --no-deps --entrypoint bash openclaw-standalone-cli -lc 'cd /home/node/.openclaw && bash skills/backup-state-to-drive/scripts/backup-state-to-drive.sh'
```

This script reads `skills/backup-state-to-drive/state.include`, creates a `tar.gz` with the durable non-workspace state, and uploads it with `gog` to `backups/<project-folder>/YYYYMMDD-HHmmss-backup/state-backup.tar.gz`.

Requirements:
- `gog` is installed in the image
- `gog` is already authenticated with Google Drive write access

## Restore Agent
Step 1. Create a clean agent with `clow-docker init`.
This recreates the Docker wrapper project with an empty `/.openclaw`.

```bash
mkdir -p claw-agent
cd claw-agent
curl -fsSL "https://raw.githubusercontent.com/quintolabs-es/5l-claw-docker/main/scripts/clow-docker.sh?skip-cache=$(date +%s)" | bash -s -- init
```

Step 2. Clone the `.openclaw` repo into the clean agent.
This restores the nested `.git` repo and brings back the latest backed up `workspace/`.

```bash
git clone <git-remote-url> ./.openclaw
```

Step 3. Open the standalone CLI.
This gives you a shell with access to `/.openclaw` and `gog`.

```bash
docker compose run --rm --no-deps --entrypoint bash openclaw-standalone-cli
```

Step 4. Create a temporary restore folder.
This keeps the downloaded archive and extracted files separate from the live state.

```bash
mkdir -p /home/node/.openclaw/restore
```

Step 5. Find and download the state backup from Drive.
This restores the durable non-workspace state captured in the Drive backup.

```bash
gog drive search "name contains 'backup' and trashed=false" --json
gog drive download <fileId> --out /home/node/.openclaw/restore/backup.tar.gz
tar -xzf /home/node/.openclaw/restore/backup.tar.gz -C /home/node/.openclaw/restore
```

Step 6. Copy the restored state into `/.openclaw` without overwriting `.git`.
This restores onboarding, auth, config, skills, and other durable state while keeping the cloned repo metadata intact.

```bash
find /home/node/.openclaw/restore -mindepth 1 -maxdepth 1 ! -name '.git' -exec cp -R {} /home/node/.openclaw/ \;
```

At the end of this restore flow, `workspace/` comes from the Git repo and the rest of the durable agent state comes from the Drive backup.
