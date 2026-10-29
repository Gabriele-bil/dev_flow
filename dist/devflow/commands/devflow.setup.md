---
name: devflow.setup
description: Generate or update AGENTS.md, REGISTRY.md, and docs/product.md in the consumer project root from adapter templates with a mandatory full questionnaire.
argument-hint: "[--force] [--mcp]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

Use `${CLAUDE_PLUGIN_ROOT}/skills/devflow-setup/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, run without `--force`/`--mcp` (managed sections only).
