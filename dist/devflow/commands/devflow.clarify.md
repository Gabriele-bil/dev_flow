---
name: devflow.clarify
description: Optional interactive session between devflow.task and devflow.plan. Resolves [NEEDS CLARIFICATION ...] markers and high-risk assumptions in task.md via structured Q&A, then sets Status clarified.
argument-hint: "[optional-task-path]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-clarify/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
