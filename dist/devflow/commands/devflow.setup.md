---
name: devflow.setup
description: Generate or update AGENTS.md, REGISTRY.md, and docs/product.md in the consumer project root from adapter templates with a mandatory full questionnaire.
argument-hint: [--force]
disable-model-invocation: true
model: sonnet
effort: medium
---

Use `@devflow/skills/devflow-setup/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Read `@devflow/config.md`, resolve the active adapter, then read `@devflow/adapters/<adapter>/ADAPTER.md` (core) + `steps/setup.md`.
- Load adapter templates from `adapters/<adapter>/templates/`; if missing, fall back to `@devflow/skills/devflow-setup/templates/`.
- Read `AGENTS.template.md`, `REGISTRY.template.md`, and `PRODUCT.template.md` from the resolved template source.
- Run mandatory full questionnaire to collect all placeholder values before rendering.
- Preserve `code-review-graph` skill references from templates in the generated `AGENTS.md`.
- Write `AGENTS.md`, `REGISTRY.md`, and `docs/product.md` in the consumer project root using `devflow-managed` block markers.
- After file writes, install adapter setup dependencies declared in `@devflow/adapters/<adapter>/steps/setup.md` under `Setup dependencies`.
- If `$ARGUMENTS` contains `--force`, overwrite full files; otherwise only replace `devflow-managed` sections.

Optional flag:
`$ARGUMENTS`
