---
name: devflow.resume
description: Resume an interrupted DevFlow session — read saved state, cross-check plan.md, confirm position, re-enter the correct pipeline step.
argument-hint: "[optional-feature]"
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-resume/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resume the feature resolved with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve`.
