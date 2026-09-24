---
name: devflow.rollback
description: Roll back the active DevFlow step (implement or beautify) to its pre-step checkpoint without corrupting pipeline state.
argument-hint: [--to <step>] [--force]
disable-model-invocation: true
---

Use `@devflow/skills/devflow-rollback/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Resolve active feature and target step to roll back.
- Locate the pre-step git checkpoint tag (`devflow-checkpoint/<branch>/<step>`).
- Revert application code changes to the checkpoint commit.
- Reset `plan.md` status and markers (`[pending]` markers for implement, `implemented` for beautify).
- Synchronize `.devflow-state.json` to the preceding valid step.
