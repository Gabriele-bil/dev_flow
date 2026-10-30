---
name: devflow.plan
description: Create a DevFlow implementation plan from a task using the devflow-plan skill workflow.
argument-hint: "[optional-task-path]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-plan/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
