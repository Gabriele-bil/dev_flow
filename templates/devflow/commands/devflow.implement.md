---
name: devflow.implement
description: Implement all files from a DevFlow plan using the devflow-implement skill workflow. Use when running the implementation step of the DevFlow pipeline.
argument-hint: "[optional-plan-path]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-implement/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).
