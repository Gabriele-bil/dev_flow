---
name: devflow.auto
description: Full-cycle autonomous delivery: chains task → plan → analyze → implement → beautify → test → ship → pr from a raw feature idea directly to an opened pull request in total autonomy.
argument-hint: "[idea-or-attached-context] [--app <name>]"
disable-model-invocation: true
---

Use `@devflow/skills/devflow-auto/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Executes the complete pipeline from idea to PR: `task → plan → analyze → implement → beautify → test → ship → pr`.
- Operates in total autonomy once invoked: arm run mode immediately (`feature: null`, `from: "task"`, `until: "pr"`, `orchestrator: "devflow.auto"`) without pausing for confirmation if idea is provided.
- Stop ONLY on major discrepancies (Critical Constitution violations, Critical analyze contradictions, unresolvable test/build Level 5 blocks, Critical ship blockers, missing monorepo app).
- For minor discrepancies, ambiguities, or non-critical findings: pick defensible defaults, continue forward, and document them in `plan.md ## Decision flags` / `task.md ## Notes` and prominently in the Pull Request description.
- Never edit protected configs (`devflow/config.md`, CI/tooling configs).
- Delete `.devflow-run.json` on every exit path (PR opened, block, handoff).

User input (idea or attached file context, plus optional `--app`):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the feature idea before proceeding.
