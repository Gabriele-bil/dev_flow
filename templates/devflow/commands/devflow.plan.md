---
name: devflow.plan
description: Create a DevFlow implementation plan from a task using the devflow-plan skill workflow.
argument-hint: [optional-task-path]
disable-model-invocation: true
model: sonnet
effort: high
---

Use `@devflow/skills/devflow-plan/SKILL.md` and execute it exactly.

Enter plan mode — read only, no code changes until `plan.md` is written.

**Anchors (do not skip):**

- Read `task.md`, `constitution.md`, and `registry.md`; extend with cited sources only as the skill directs.
- Write `plan.md` in the **same** directory as the task: `devflow/features/[NNN]_[feature-name]/plan.md`.
- Order the **File list** bottom-up (migrations/schema → domain → data → providers → UI → i18n/codegen when applicable).
- Include the **Traceability** table mapping each original subtask to file path(s); prefer vertical slices when the skill calls for it.

Optional input (task path):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, resolve the task at `devflow/features/*/task.md` with the **highest existing `NNN_` numeric prefix** and proceed.
