---
name: devflow.pr
description: Commit, push, and open a PR for the current DevFlow feature using the devflow-pr skill workflow.
argument-hint: "[optional notes for PR body]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-pr/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, derive PR title/body from `task.md` + `plan.md`.
