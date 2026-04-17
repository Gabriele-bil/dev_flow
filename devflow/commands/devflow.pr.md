---
name: devflow.pr
description: Commit, push, and open a PR for the current DevFlow feature using the devflow-pr skill workflow.
argument-hint: [optional notes for PR body]
disable-model-invocation: true
model: haiku
effort: low
---

Use `@devflow/skills/devflow-pr/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Read `@devflow/config.md` and the active `ADAPTER.md` for pre-push commands and PR checklist items.
- Run the adapter’s verification commands and capture real output before ticking checklist items.
- Commit with a single conventional message; push `[type]/[NNN]-[feature-name]`; open PR toward `main` with `gh pr create`.

Optional steering for PR body or title:
`$ARGUMENTS`
