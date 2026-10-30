---
name: devflow.analyze
description: Run cross-artifact consistency check on task.md and plan.md before implementation. Detects traceability gaps, untestable ACs, terminology drift, constitution violations, and coverage imbalances.
argument-hint: "[optional-feature-path]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-analyze/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
