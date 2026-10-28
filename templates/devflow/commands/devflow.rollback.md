---
name: devflow.rollback
description: Roll back the active DevFlow step (implement or beautify) to its pre-step checkpoint without corrupting pipeline state.
argument-hint: "[--to <step>] [--force]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-rollback/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, roll back the active feature's last step (skill Step 1 defaults).
