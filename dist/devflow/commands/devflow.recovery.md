---
name: devflow.recovery
description: Diagnose and recover a stuck or corrupted DevFlow pipeline — reads state, observe log, and feature files to identify failure and propose a targeted recovery.
argument-hint: "[optional-feature]"
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-recovery/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, diagnose the feature resolved per `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` → **Active feature resolution**, plus every `blocked` feature.
