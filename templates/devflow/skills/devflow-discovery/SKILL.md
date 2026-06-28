---
name: devflow-discovery
description: Orients AI agents to the dev-flow pipeline at session start. Answers "where do I begin?" by mapping current project state to the correct pipeline entry point. Injected automatically via SessionStart hook.
skip-validation: true
---

# Skill: devflow.discovery

Pipeline orientation. Use at session start or when unsure which step to run.

## Pipeline Overview

```
devflow.setup → devflow.task → devflow.plan → devflow.implement → devflow.beautify → devflow.test → devflow.pr
                             ↘ devflow.blueprint (3+ PRs / multi-session)
                               → devflow.plan (per step) → devflow.implement → ...
```

Each step has an input contract. Each step verifies its own preconditions. User is orchestrator — skills do not invoke each other.

## Entry Point Decision Tree

```
Is this a new project with no context files (AGENTS.md / REGISTRY.md / docs/product.md)?
  └─ YES → devflow.setup

Raw idea or user request, no task.md yet?
  ├─ Objective requires 3+ PRs or spans multiple sessions?
  │    └─ YES → devflow.blueprint (produces devflow/plans/[slug]-blueprint.md)
  └─ Otherwise → devflow.task

task.md exists, contains [NEEDS CLARIFICATION: ...] markers?
  └─ YES → devflow.clarify (optional, recommended before devflow.plan)

task.md exists, but no plan.md?
  └─ YES → devflow.plan  (verify task.md Status not draft with unresolved questions)

plan.md exists (Status: ready), analyze not yet run?
  └─ YES → devflow.analyze (recommended before devflow.implement)

plan.md exists (Status: ready), analyze passed (or explicitly waived), not yet implemented?
  └─ YES → devflow.implement

devflow.implement summary exists, analyze/typecheck passes, no beautify yet?
  └─ YES → devflow.beautify

devflow.beautify done, no tests yet?
  └─ YES → devflow.test

Tests passing, ready to merge?
  └─ YES → devflow.pr
```

## Quick Intent Mapping

| What user said | Entry point |
|----------------|-------------|
| "Build X", "Add X", "I want X" | `devflow.task` |
| "Plan this large objective", "3+ PRs", "multi-session" | `devflow.blueprint` |
| "Plan this", "Create plan for..." | `devflow.plan` |
| "Clarify task", "Resolve markers", "Ambiguous task" | `devflow.clarify` |
| "Verify consistency", "Cross-check plan", "Check artifacts" | `devflow.analyze` |
| "Implement", "Code this up" | `devflow.implement` |
| "Review", "Clean up", "Beautify" | `devflow.beautify` |
| "Write tests", "Test this" | `devflow.test` |
| "Open PR", "Commit", "Ship" | `devflow.pr` |
| "Set up project", "Initialize" | `devflow.setup` |

## Adapter Resolution (every step except task and setup)

1. Read `@devflow/config.md` — get active adapter
2. Read `@devflow/adapters/<adapter>/ADAPTER.md` — authoritative for stack rules

Current adapters: `flutter`, `angular`, `nextjs`. Common skills: `@devflow/adapters/common/skills/`.

## Anti-Rationalization

| Thought | Reality |
|---------|---------|
| "Skip to implement — idea is obvious" | `task.md` + `plan.md` traceability prevent missing coverage. Start at correct entry point |
| "Merge steps to go faster" | Each step contract prevents silent gaps. Speed comes from correctness, not skipping |
| "This is too small for the full pipeline" | Small features break too. Use pipeline from correct entry point — skip only if input contract already satisfied |

## Key Principles

- **Traceability:** every subtask in `task.md` maps to file(s) in `plan.md`. `devflow.implement` proves all covered.
- **Beyonce Rule:** behavior that matters deserves a test. No exceptions.
- **Chesterton's Fence:** don't remove code without understanding why it exists.
- **Rule of 500:** file over 500 lines → split. SRP breakdown signal.
- **Stop-the-Line:** when implement hits unresolvable errors → stop, report, do not invent behavior.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Jumping to `devflow.implement` without checking state | Skips plan approval; implement runs on stale or missing plan | Always check `.devflow-state.json` entry point before any action |
| Using discovery as a full planning session | Discovery is orientation only — not a planning step | Read state, identify entry point, route; planning happens in `devflow.plan` |
| Treating discovery output as instructions from user | Discovery is injected by SessionStart hook; it is context, not a user command | Follow discovery routing, do not re-interpret it |

## I/O Reference

| | |
|---|---|
| Injected by | `hooks/session-start.sh` at SessionStart |
| Reads | Nothing — orientation only |
| Leads to | Correct pipeline entry point for current state |
