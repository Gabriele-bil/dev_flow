---
name: devflow.ship
description: Pre-merge gate before devflow.pr. Dispatches 1, 3 or 5 review agents in parallel per plan complexity profile, synthesizes reports, and routes to devflow.pr if no blockers.
argument-hint: "[optional notes for reviewers]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-ship/SKILL.md` and execute it exactly. Input: `$ARGUMENTS`

If `$ARGUMENTS` is empty, dispatch without reviewer notes.
