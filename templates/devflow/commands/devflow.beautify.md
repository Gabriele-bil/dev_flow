---
name: devflow.beautify
description: Review and improve devflow.implement output using the devflow-beautify skill workflow.
argument-hint: "[optional-plan-path]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-beautify/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
