---
name: devflow.ship
description: Pre-merge gate before devflow.pr. Dispatches 1, 3 or 5 review agents in parallel per plan complexity profile, synthesizes reports, and routes to devflow.pr if no blockers.
argument-hint: "[optional notes for reviewers]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-ship/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, dispatch without reviewer notes.
