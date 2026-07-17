---
name: devflow.implement
description: Implement all files from a DevFlow plan using the devflow-implement skill workflow. Use when running the implementation step of the DevFlow pipeline.
argument-hint: [optional-plan-path]
disable-model-invocation: true
model: sonnet
effort: medium
---

Use `@devflow/skills/devflow-implement/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Before branch operations, classify local changes per the skill:
  - allowed dirty state: DevFlow pipeline artifacts (for example `devflow/features/*/task.md`, `devflow/features/*/plan.md`, and feature docs updated by prior DevFlow steps)
  - disallowed dirty state: unrelated source/config changes
- If dirty state is allowed, do **not** block the run; avoid destructive cleanup and follow the skill's branch fallback rules.
- Implement files in **File list** order only.
- Read `@devflow/config.md` and the active adapter core (`ADAPTER.md`) + `steps/implement.md` for MCP usage and verify commands.
- Run format, analyze/typecheck, and conditional codegen per the skill and the adapter implement step file; hand off only when analyze is clean or remaining issues are explicitly documented.
- If those steps still fail after the skill’s retry budget, stop ad-hoc patching and follow **systematic debugging** (e.g. superpowers `systematic-debugging`) before continuing.

Optional input (plan path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the plan at `devflow/features/*/plan.md` with the **highest existing `NNN_` numeric prefix** and proceed.
