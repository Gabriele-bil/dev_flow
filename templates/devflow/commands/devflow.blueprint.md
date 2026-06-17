---
name: devflow.blueprint
description: Transform a large objective into a multi-PR blueprint with dependency graph, parallel-step detection, and adversarial review gate.
argument-hint: [objective or path-to-brief]
disable-model-invocation: true
model: opus
effort: high
---

Use `@devflow/skills/devflow-blueprint/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Read `docs/product.md`, `constitution.md`, `registry.md` before decomposing into steps.
- Every step must have a self-contained context brief — a fresh agent must be able to execute it with no prior-session knowledge.
- Run the adversarial review gate (Opus subagent) before writing the final file. Do not skip it.
- Mark parallel-safe only when you can prove no shared files or contracts. Default is `no`.
- Write `devflow/plans/[slug]-blueprint.md` in the project root.

User input (objective or attached brief):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the objective before proceeding.
