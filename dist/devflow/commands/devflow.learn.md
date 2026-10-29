---
name: devflow.learn
description: Manage local and shared team instincts — log findings, search lessons, list entries, prune stale items, boost confidence, or promote local instincts to team-shared storage and REGISTRY.md.
argument-hint: "[log | search <query> | list | check | prune | boost <id> | promote <id>]"
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-learn/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, run `list`.
