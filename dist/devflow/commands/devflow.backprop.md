---
name: devflow.backprop
description: Backpropagate a bug or failing test into the spec — trace to acceptance criterion, classify the gap, tighten task.md, add regression test.
argument-hint: "[bug-description-or-test-path]"
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-backprop/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the observed failure before Step 1.
