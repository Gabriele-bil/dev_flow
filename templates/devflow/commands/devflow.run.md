---
name: devflow.run
description: Chain implement → beautify → test as one unattended session — decision flags instead of pauses, consolidated report, stop before ship.
argument-hint: [--from implement|beautify|test] [--until beautify|test|ship]
disable-model-invocation: true
---

Use `@devflow/skills/devflow-run/SKILL.md` and execute it exactly.

**Anchors (do not skip):**

- Arm run mode only after the Step 0 user confirmation; write `.devflow-run.json` per `@devflow/references/state-machine.md` → **Run marker**.
- Honor the **Autonomy policy** table: never commit, push, open PR, edit configs, or apply opinable beautify changes unattended.
- Ambiguity → defensible default + entry in `plan.md` `## Decision flags`; never silent picks, never invented product rules.
- Delete `.devflow-run.json` on every exit path (complete, contract failure, block, handoff).
- Stop before `devflow.ship` (default) with the consolidated report; `--until ship` never routes to `devflow.pr`.

Optional input (flags):
`$ARGUMENTS`

If `$ARGUMENTS` is empty, use `--from implement --until test` on the plan at `devflow/features/*/plan.md` with the **highest existing `NNN_` numeric prefix**.
