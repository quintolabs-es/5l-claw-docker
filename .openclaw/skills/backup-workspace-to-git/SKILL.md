---
name: backup-workspace-to-git
description: Use this skill when repo-tracked agent workspace content under `.openclaw` changed and those changes should be persisted to the git repo rooted at `.openclaw`. The tracked content is defined by `.openclaw/.gitignore`, which by default includes `workspace/` and `skills/`.
---

Use this skill when meaningful repo-tracked agent workspace changes were made and they should be backed up to the `.openclaw` git repo.

Use it after changes to:
- workspace content
- skills

Run:

```bash
bash skills/backup-workspace-to-git/scripts/backup-workspace-to-git.sh
```

If the script reports there is nothing to commit, stop there.
