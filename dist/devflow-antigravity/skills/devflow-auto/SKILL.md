---
name: devflow-auto
description: "Full-cycle autonomous delivery: turns a raw feature idea directly into an opened pull request via task, plan, analyze, implement, beautify, test, ship, and pr. Operates in total autonomy, choosing defensible defaults and documenting minor discrepancies in the pull request; halts only on major discrepancies (Critical blockers). Use when user runs devflow.auto or asks to deliver end to end from idea to PR automatically without pausing for questions."
argument-hint: "[idea-or-attached-context] [--app <name>]"
---

# Skill: devflow.auto

## Quick Start

Run `/devflow.auto <idea> [--app <name>]`.

- `devflow.run` with the `task → pr` preset: `task → plan → analyze → implement → beautify → test → ship → pr`, unattended from raw idea to opened PR
- `--app <name>`: required only when `devflow/config.md` has a `## Apps` table (monorepo)

## Purpose

End-to-end autonomous delivery from raw idea to opened PR. Same contract as `devflow.run` (`@devflow/references/run-mode.md`, `auto` column) — extended upstream (task, plan, analyze) and downstream (ship → pr). Halts only on major discrepancies; minor ones become decision flags surfaced in the PR body.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` generated and verified
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Idea maps to existing/planned feature in `docs/product.md` — `task.md` exists → `devflow.plan` or `devflow.run`
- Idea brainstorm-scale (no concrete problem or user) — `devflow-task` Step 3 routes it away; auto never defaults around it
- User wants step-by-step review — individual commands
- Interrupted run — `devflow.resume`; corrupted state — `devflow.recovery`

## Input contract

Collected **before** arming — no user prompt after Step 0:

- [ ] Idea text (or attached context) in `$ARGUMENTS` — empty → ask
- [ ] No active `.devflow-run.json` — stale → ask user: delete or `devflow.recovery`
- [ ] Monorepo (`## Apps` table) → `--app` valid, or ask now — never guessed later

Any item fails → stop, report, do not arm.

## Workflow

### Step 0 - Arm

Arm per `@devflow/references/run-mode.md` → **Marker**, immediately (no confirmation): `feature: null`, `from: "task"`, `until: "pr"`, `orchestrator: "devflow.auto"`, `ship_grader_iterations: 2`, `ship_grader_iteration_count: 0`. Announce: `🤖 devflow.auto: task → plan → analyze → implement → beautify → test → ship → pr (unattended; halts only on major discrepancies)`.

### Step 1 - Chain

Every step: full skill workflow, run-mode clauses active, status boundaries written. Stop/continue per **Discrepancy classes** in `run-mode.md`.

1. `@devflow/skills/devflow-task/SKILL.md` — after Step 9 writes `task.md`, set marker `feature` to `NNN_name`.
2. `@devflow/skills/devflow-plan/SKILL.md`.
3. `@devflow/skills/devflow-analyze/SKILL.md` — Critical → stop; Required/Nit → plan adjustment or waiver flag.
4. Middle pipeline — `devflow-run` Step 1 chain rules, `--from implement --until ship`: implement → beautify → test (incl. Step 6b) → ship.
5. Ship gate passes (or loop cap reached with exceptions flagged) → `devflow-ship` Step 5 executes `@devflow/skills/devflow-pr/SKILL.md`; PR body carries `## Autonomous Decisions & Discrepancies` from `## Decision flags`, `## Deviations`, `task.md` `## Assumptions & Risks`.

### Step 2 - Disarm + report

Disarm per `run-mode.md` → **Disarm** (every exit path). Report:

```text
🤖 devflow.auto [complete: idea → PR opened | stopped at <step>: <major discrepancy>]

Feature:  [NNN]_[feature-name]  ·  Status: [plan.md Status or "task only"]
Branch:   [type]/[NNN]_[feature-name]   PR: [URL, when opened]
Steps:    task · plan · analyze · implement · beautify · test · ship · pr  [✅/❌ each]
Flags:    [N] decision flags / discrepancies (in PR body when opened)
[Blocker + action required, when stopped — continue with devflow.resume or interactive commands]
```

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Idea is ambiguous — pause and ask" | Inputs needing the user are collected before arming; afterwards default + flag |
| "Analyze/ship Required finding — stop" | Only major discrepancies stop auto; Required → fix loop / waiver flag → PR |
| "Constitution violation is minor here" | Constitution Gate violations always hard-stop |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Asking the user mid-chain | Collect idea/app/stale-marker decisions before Step 0 |
| Re-stating run-mode rules per step | `@devflow/references/run-mode.md` is the contract — cite, don't copy |
| Silent defaults | Every autonomous choice → `## Decision flags` → PR body |
| Leaving `.devflow-run.json` after exit | Disarm on every exit path |

## I/O Reference

| | |
| --- | --- |
| Reads | `@devflow/references/run-mode.md`, `@devflow/references/state-machine.md` (run marker, handoff), `@devflow/references/escalation-ladder.md`, `@devflow/references/adapter-resolution.md` |
| Executes | `devflow-task`, `devflow-plan`, `devflow-analyze`, then `devflow-run` chain (`devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-ship`) → `devflow-pr` |
| Writes | `.devflow-run.json` (armed Step 0, `feature` set after task, deleted Step 2); feature artifacts via chained skills |
| Output | Opened PR with autonomous decisions & discrepancies section |
| Related | `devflow-run` (middle pipeline only), `devflow-resume`, `devflow-recovery` |
