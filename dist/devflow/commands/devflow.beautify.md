---
name: devflow.beautify
description: Review and improve devflow.implement output using the devflow-beautify skill workflow.
argument-hint: "[optional-plan-path]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-beautify/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
