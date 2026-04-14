---
name: backup-state-to-drive
description: Use this skill when durable `.openclaw` onboarding or auth state should be archived and uploaded to Google Drive with `gog`. It packages the paths listed in `state.include` and uploads the archive into `backups/<project-name>/`.
---

Use this skill when important durable agent state changed and it should be backed up to Google Drive.

Use it after changes to:
- onboarding or gateway config
- tool authentication or paired devices
- local skills, secrets, or identity files

Requirements:
- `gog` is installed in the container
- `gog` is already authenticated with Google Drive write access

Run:

```bash
bash skills/backup-state-to-drive/scripts/backup-state-to-drive.sh
```

If the script reports missing files, it skips them and still backs up what exists.
