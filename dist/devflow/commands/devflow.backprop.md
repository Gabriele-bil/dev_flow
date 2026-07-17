---
name: devflow.backprop
description: Backpropagate a bug or failing test into the spec — trace to acceptance criterion, classify the gap, tighten task.md, add regression test.
argument-hint: [bug-description-or-test-path]
---

Use `@devflow/skills/devflow-backprop/SKILL.md` and execute it exactly.

Optional input (bug description or failing test path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the observed failure before Step 1.
