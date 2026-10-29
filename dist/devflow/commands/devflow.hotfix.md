---
name: devflow.hotfix
description: Fast-track pipeline for critical bugfixes, targeted patches, or hotfixes — compact task+plan, implement, targeted test, and quick ship gate directly to PR.
argument-hint: "<bug-description>"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-hotfix/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the bug description before proceeding.
