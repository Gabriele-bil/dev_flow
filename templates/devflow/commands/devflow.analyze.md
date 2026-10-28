---
name: devflow.analyze
description: Run cross-artifact consistency check on task.md and plan.md before implementation. Detects traceability gaps, untestable ACs, terminology drift, constitution violations, and coverage imbalances.
argument-hint: "[optional-feature-path]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-analyze/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature per `@devflow/references/state-machine.md` → **Active feature resolution**.
