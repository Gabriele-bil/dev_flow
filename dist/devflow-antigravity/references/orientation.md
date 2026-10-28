# DevFlow Orientation

Session-start routing: map project state to one entry point. Context, not a user command — route, don't plan.

```text
init ─────────────────────────────────┐
[discover] → setup → task → [clarify] ┼→ plan → [analyze] → implement → beautify → test → ship → pr
              blueprint (3+ PRs) ─────┘
```

Statuses + transitions: `@devflow/references/state-machine.md`. Active feature: its **Active feature resolution**. `plan.md` Status wins over `.devflow-state.json`.

## Decision tree (first match wins)

```text
No devflow/config.md?
  greenfield, empty repo → devflow.init
  existing code          → devflow.setup
Stack / architecture undecided?          → devflow.discover
.devflow-run.json, handoff.md, or plan Status implementing? → devflow.resume
plan Status blocked, or state inconsistent? → devflow.recovery
Urgent bug, root cause known, ≤3 files?  → devflow.hotfix
Raw idea, no task.md:
  3+ PRs / multi-session                 → devflow.blueprint
  otherwise                              → devflow.task
task.md has [NEEDS CLARIFICATION]        → devflow.clarify
task.md, no plan.md                      → devflow.plan
plan Status:
  ready        → devflow.analyze (recommended) → devflow.implement
  implementing → devflow.implement (resumes first [pending])
  implemented  → devflow.beautify
  beautified   → devflow.test
  tested       → devflow.ship
  shipped      → devflow.pr
  pr-opened    → next open feature, or devflow.task
Bug escaped a passing pipeline           → devflow.backprop
"Where am I?"                            → devflow.status
```

Opt-in autonomy, explicit command only: `/devflow.run` (implement → test unattended), `/devflow.auto` (idea → PR). Contract: `@devflow/references/run-mode.md`.

## Rules

- User orchestrates; only `ship`, `run`, `auto`, `hotfix` chain other skills.
- Every entry skill checks its input contract — never skip a step or bypass a contract.
- Adapter + app: `@devflow/references/adapter-resolution.md` (all steps except task/setup).
- Code-index MCP available → index-first exploration per `@devflow/references/token-economy.md`.
