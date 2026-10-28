---
name: devflow.blueprint
description: Transform a large objective into a multi-PR blueprint with dependency graph, parallel-step detection, and adversarial review gate.
argument-hint: "[objective or path-to-brief]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-blueprint/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the objective before proceeding.
