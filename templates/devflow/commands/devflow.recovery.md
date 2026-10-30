---
name: devflow.recovery
description: Diagnose and recover a stuck or corrupted DevFlow pipeline — reads state, observe log, and feature files to identify failure and propose a targeted recovery.
argument-hint: "[optional-feature]"
---

Use `@devflow/skills/devflow-recovery/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, diagnose the feature resolved with `bash "@devflow/scripts/devflow-state.sh" resolve`, plus every `blocked` feature.
