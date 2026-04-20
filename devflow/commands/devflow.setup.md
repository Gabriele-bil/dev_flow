---
name: devflow.setup
description: Generate or update AGENTS.md and REGISTRY.md in the consumer project root from adapter templates.
argument-hint: [--force]
disable-model-invocation: true
model: sonnet
effort: medium
---

Use `@devflow/skills/devflow-setup/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Read `@devflow/config.md`, resolve the active adapter, then read `@devflow/adapters/<adapter>/ADAPTER.md`.
- Load adapter templates from `adapters/<adapter>/templates/`; if missing, fall back to `@devflow/skills/devflow-setup/templates/`.
- Write `AGENTS.md` and `REGISTRY.md` in the consumer project root using `devflow-managed` block markers.
- If `$ARGUMENTS` contains `--force`, overwrite full files; otherwise only replace `devflow-managed` sections.

Optional flag:
`$ARGUMENTS`
