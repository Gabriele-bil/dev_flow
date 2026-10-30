---
name: devflow.test
description: Write and execute DevFlow feature tests using the devflow-test skill workflow.
argument-hint: "[optional-plan-path]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-test/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
