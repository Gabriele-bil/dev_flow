---
name: devflow.rollback
description: Roll back the active DevFlow step (implement or beautify) to its pre-step checkpoint without corrupting pipeline state.
argument-hint: "[--to <step>] [--force]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-rollback/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, roll back the active feature's last step (skill Step 1 defaults).
