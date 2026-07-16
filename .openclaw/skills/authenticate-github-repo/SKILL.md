---
name: authenticate-github-repo
description: Use this skill when the user asks the agent to authenticate against a GitHub repo so it can clone it into `.openclaw/workspace/repos/<repo>` and later use normal git pull/push commands against that repo.
---

Use this skill when the user wants the agent to connect a GitHub repo for future cloning and pushing.

Run it in two phases so the user can add the deploy key in GitHub between them.

1. Prepare auth material and print the public key plus GitHub instructions:

```bash
bash skills/authenticate-github-repo/scripts/authenticate-github-repo.sh prepare --github-repo-url <https://github.com/owner/repo>
```

2. Show the printed public key value to the user and wait until the user confirms the deploy key was added in GitHub.

3. Finalize auth and clone the repo into `workspace/repos/<repo>`:

```bash
bash skills/authenticate-github-repo/scripts/authenticate-github-repo.sh finalize --github-repo-url <https://github.com/owner/repo>
```

If the script reports an existing local clone path, an existing conflicting auth profile, or another unexpected collision, stop and ask the user what to do.

If the user wants to discard the previous repo-specific auth material and recreate it, rerun `prepare` with:

```bash
bash skills/authenticate-github-repo/scripts/authenticate-github-repo.sh prepare --github-repo-url <https://github.com/owner/repo> --replace-auth
```

If the user wants to delete the previous clone and recreate it, rerun `finalize` with:

```bash
bash skills/authenticate-github-repo/scripts/authenticate-github-repo.sh finalize --github-repo-url <https://github.com/owner/repo> --replace-clone
```
