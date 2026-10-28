---
name: devflow.setup
description: Generate or update AGENTS.md, REGISTRY.md, and docs/product.md in the consumer project root from adapter templates with a mandatory full questionnaire.
argument-hint: "[--force] [--mcp]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-setup/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, run without `--force`/`--mcp` (managed sections only).
