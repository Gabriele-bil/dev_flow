---
name: devflow.beautify
description: Review and improve devflow.implement output using the devflow-beautify skill workflow.
argument-hint: [optional-plan-path]
disable-model-invocation: true
model: haiku
effort: medium
---

Use `@devflow/skills/devflow-beautify/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Scope: only files touched by the current `devflow.implement` run (see skill for edge cases).
- Tag every finding with the skill’s severities (**Critical**, required with no prefix, **Nit**, **Optional** / **Consider**, **FYI**) and include **file path and line references** where applicable.
- Summarize completion using the skill template: **Findings by severity** (Critical / Required / Nit·Optional·FYI) plus **Improvements by area**; do not refactor unrelated or pre-existing code outside the implement summary.
- After edits: run format / analyze / conditional codegen per `@devflow/config.md` → active `ADAPTER.md` and the skill’s Step 5.

Optional input (`plan.md` path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, follow the skill Quick Start: **use the file most recently modified in git** to establish scope (do not default to “latest” `plan.md` by numeric prefix alone).
