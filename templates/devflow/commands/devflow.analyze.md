---
name: devflow.analyze
description: Run cross-artifact consistency check on task.md and plan.md before implementation. Detects traceability gaps, untestable ACs, terminology drift, constitution violations, and coverage imbalances.
argument-hint: [optional-feature-path]
disable-model-invocation: true
model: haiku
effort: low
---

Use `@devflow/skills/devflow-analyze/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Read `task.md`, `plan.md`, and `constitution.md` only — no file writes allowed.
- Run all 5 passes (A through E) even when earlier passes find findings — always produce a complete report.
- Report each finding with severity (Critical / Required / Nit) and a one-line suggested fix.
- End the report with the blocker count and a clear proceed / stop signal.

Optional input (feature path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the feature at `devflow/features/*/plan.md` with the **highest existing `NNN_` numeric prefix** and proceed.
