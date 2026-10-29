---
name: devflow.test
description: Write and execute DevFlow feature tests using the devflow-test skill workflow.
argument-hint: "[optional-plan-path]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-test/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature per `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` → **Active feature resolution**.
