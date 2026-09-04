---
name: devflow.auto
description: Chain task → plan → analyze → implement as one unattended session from a raw feature idea — decision flags instead of pauses, consolidated report, stop before beautify.
argument-hint: [idea-or-attached-context] [--app <name>]
disable-model-invocation: true
---

Use `@devflow/skills/devflow-auto/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Arm run mode only after the Step 0 user confirmation; write `.devflow-run.json` (`feature: null`, `from: "task"`, `until: "implement"`) per `@devflow/references/state-machine.md` → **Run marker**.
- Honor the **Autonomy policy** table: never commit, push, open PR, edit configs, guess a missing monorepo `--app`, bypass Constitution Gate Critical/Required, or proceed past `devflow.analyze` Critical/Required findings.
- Ambiguity in `devflow.task` → entry in `task.md` `## Notes`; ambiguity in `devflow.plan` → entry in `plan.md` `## Decision flags`. Never silent picks, never invented product rules.
- Update `.devflow-run.json` `feature` field once `task.md` is written; delete the marker on every exit path (complete, contract failure, block, handoff).
- Stop before `devflow.beautify` with the consolidated report.

User input (idea or attached file context, plus optional `--app`):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, ask the user for the feature idea before proceeding.
