# Backup And Restore

## Backup Workspace To Git
```bash
docker compose run --rm --no-deps --entrypoint bash openclaw-standalone-cli -lc 'bash skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh'
```

This script stages only `workspace/` in the nested `.openclaw` git repo, creates a commit if there are changes, and pushes when `origin` exists.

## Backup Agent State To Drive
```bash
docker compose run --rm --no-deps --entrypoint bash openclaw-standalone-cli -lc 'bash skills/backup-state-to-drive/scripts/backup-state-to-drive.sh'
```

This script reads `skills/backup-state-to-drive/state.include`, creates a `tar.gz` with the durable non-workspace state under a top-level `.openclaw/` folder, and uploads it with `gog` to `backups/<project-folder>/YYYYMMDD-HHmmss-state-backup.tar.gz`.

Requirements:
- `gog` is installed in the image
- `gog` is already authenticated with Google Drive write access

## Restore Agent
Restore is the normal onboarding flow described in [README.onboard.md](./README.onboard.md). At the end go through the `Initialize Agent Workspace And State` section.
