---
name: devflow.discover
description: Explore architectural choices for app creation or complex features, compare technical trade-offs, and generate formal ADRs.
argument-hint: "[--app <name>] [--feature <slug>] [topic-or-scope]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-discover/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user which architectural choice or feature to explore.
