---
name: devflow.hotfix
description: Fast-track pipeline for critical bugfixes, targeted patches, or hotfixes — compact task+plan, implement, targeted test, and quick ship gate directly to PR.
argument-hint: "<bug-description>"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-hotfix/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the bug description before proceeding.
