---
name: devflow.resume
description: Resume an interrupted DevFlow session — read saved state, cross-check plan.md, confirm position, re-enter the correct pipeline step.
argument-hint: "[optional-feature]"
---

Use `@devflow/skills/devflow-resume/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, resume the feature resolved with `bash "@devflow/scripts/devflow-state.sh" resolve`.
