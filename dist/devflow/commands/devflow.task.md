---
name: devflow.task
description: Create a DevFlow task from a raw feature idea using the devflow-task skill workflow.
argument-hint: "[idea-or-attached-context] [--app <name>]"
disable-model-invocation: true
model: haiku
effort: low
---

Use `@devflow/skills/devflow-task/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- If `devflow/config.md` declares a `## Apps` table, resolve the target app first (`--app <name>` or ask) — single-app repos skip this, unchanged.
- Read `docs/product.md` always; use `constitution.md` / `registry.md` as needed to ground scope.
- If the idea is vague, ambiguous, or missing actors or success criteria, stop and ask (max 5 concise questions) before writing `task.md`.
- Automatically derive the feature name and commit type, and set the git branch using the `[type]/[number-of-task-is-present]_[name]` convention; never ask the user for the branch name.
- Assign the next unique `NNN_` prefix under `devflow/features/`; never reuse an existing prefix.
- Deliver `devflow/features/[NNN]_[feature-name]/task.md` with Connextra user story, structured use cases, BDD acceptance criteria, explicit async states, and set branch.

User input (idea or attached file context):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the feature idea before proceeding.
