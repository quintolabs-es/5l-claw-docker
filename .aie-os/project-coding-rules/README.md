# Project Coding Rules

Add repo-specific markdown files here.

- `critical-rules.md` is lifted into the top `Critical Rules` section.
- Any other `*.md` file is appended under `Project Coding Rules`.
- `README.md` is ignored by build.

## `critical-rules.md`

```md
- Confirm backward-incompatible changes before implementing them.
- Keep externally visible behavior explicit when this repo changes public contracts.
```

## `repo-rules.md`

```md
- Keep feature-specific code close together in this repo.
- Prefer small adapters around external services used by this repo.
```
