---
name: devflow-discovery
description: Orients AI agents to the dev-flow pipeline at session start. Answers "where do I begin?" by mapping current project state to the correct pipeline entry point. Injected automatically via SessionStart hook.
skip-validation: true
---

# Skill: devflow.discovery

Pipeline orientation. Use at session start or when unsure which step to run.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Pipeline Overview

```
devflow.setup → devflow.task → devflow.plan → devflow.implement → devflow.beautify → devflow.test → devflow.pr
```

Each step has an input contract. Each step verifies its own preconditions. User is orchestrator — skills do not invoke each other.

## Entry Point Decision Tree

```
Is this a new project with no context files (AGENTS.md / REGISTRY.md / docs/product.md)?
  └─ YES → devflow.setup

Raw idea or user request, no task.md yet?
  └─ YES → devflow.task

task.md exists, but no plan.md?
  └─ YES → devflow.plan  (verify task.md Status not draft with unresolved questions)

plan.md exists (Status: ready), not yet implemented?
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
| "Plan this", "Create plan for..." | `devflow.plan` |
| "Implement", "Code this up" | `devflow.implement` |
| "Review", "Clean up", "Beautify" | `devflow.beautify` |
| "Write tests", "Test this" | `devflow.test` |
| "Open PR", "Commit", "Ship" | `devflow.pr` |
| "Set up project", "Initialize" | `devflow.setup` |

## Adapter Resolution (every step except task and setup)

1. Read `@devflow/config.md` — get active adapter
2. Read `@devflow/adapters/<adapter>/ADAPTER.md` — authoritative for stack rules

Current adapters: `flutter`, `angular`. Common skills: `@devflow/adapters/common/skills/`.

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

## I/O Reference

| | |
|---|---|
| Injected by | `hooks/session-start.sh` at SessionStart |
| Reads | Nothing — orientation only |
| Leads to | Correct pipeline entry point for current state |
