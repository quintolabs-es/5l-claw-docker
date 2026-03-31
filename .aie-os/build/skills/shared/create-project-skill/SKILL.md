---
name: create-project-skill
description: Use this skill when the user wants to create or update a project-specific skill under `.aie-os/project-skills/`. It creates the skill folder, writes a concise `SKILL.md`, and keeps the instructions aligned with this repo's local skill conventions.
---

# Create Project Skill

Use this skill when the user wants a new project-specific skill for the current repository.

## Outcome

- Create or update one skill folder under `.aie-os/project-skills/`.
- Keep the skill focused on one repeated repo-specific workflow.
- Write a concise `SKILL.md` with clear trigger wording and deterministic steps.

## Required input

- skill name
- what the skill should help with
- any repo-specific files, folders, or commands it must use

If the name is missing, derive a short kebab-case name from the requested workflow.

## Workflow

1. Confirm the workflow is project-specific and belongs under `.aie-os/project-skills/`.
2. Create or update `.aie-os/project-skills/<skill-name>/SKILL.md`.
3. Use YAML frontmatter with:
   - `name`
   - `description`
4. Keep the body concise and include only:
   - when to use the skill
   - required inputs
   - deterministic workflow steps
   - exact repo-local paths or commands when needed
5. Do not add extra docs such as `README.md` or changelogs.
6. If the new skill changes generated context, rebuild with `bash bin/cli build --project-path <project-path>`.

## Skill shape

```md
---
name: <skill-name>
description: Use this skill when <trigger condition>. It helps with <workflow>.
---

# <Title>

Use this skill when <trigger condition>.

## Outcome

- <result>

## Required input

- <input>

## Workflow

1. <step>
2. <step>
3. <step>
```

## Rules

- Prefer one skill per workflow.
- Keep instructions specific to this repository.
- Reference exact repo paths instead of vague descriptions.
- Keep the skill short enough to read quickly during execution.
