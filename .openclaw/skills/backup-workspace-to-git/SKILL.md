---
name: backup-workspace-to-git
description: Use this skill when `.openclaw/workspace` changed and those changes should be persisted to the git repo rooted at `.openclaw`. It stages the workspace, commits it, and pushes when a remote exists.
---

Use this skill when meaningful changes were made to the agent workspace and they should be backed up to the `.openclaw` git repo.

Use it after changes to:
- workspace content

Run:

```bash
bash skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh
```

If the script reports there is nothing to commit, stop there.
