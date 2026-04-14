---
name: backup-to-git
description: Use this skill when durable OpenClaw workspace or state changes should be persisted to the git repo rooted at .openclaw. It stages the relevant files, commits them, and pushes when a remote exists.
---

Use this skill when important durable state changed and the agent should save a backup snapshot of its `.openclaw` repo.

Use it after meaningful changes to:
- workspace content
- config or identity
- credentials or paired devices
- local skills
- committed secrets under `.openclaw/.secrets`

Do not use it for transient runtime artifacts such as media, memory, tasks, logs, or completions.

Run:

```bash
bash skills/backup-to-git/scripts/backup-state-to-git.sh
```

If the script reports there is nothing to commit, stop there.
