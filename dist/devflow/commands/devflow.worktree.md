---
name: devflow.worktree
description: Create, list, or remove isolated git worktrees for parallel DevFlow feature development, with dev-server port-offset assignment.
argument-hint: "[create|remove|list] [feature-name]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-worktree/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, run `create` for the active feature.
