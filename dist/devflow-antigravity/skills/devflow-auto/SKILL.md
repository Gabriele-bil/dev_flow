---
name: devflow-auto
description: "Full-cycle autonomous delivery: turns a raw feature idea directly into an opened pull request via task, plan, implement, test, ship, and pr (beautify opt-in). Operates in total autonomy, choosing defensible defaults and documenting minor discrepancies in the pull request; halts only on major discrepancies (Critical blockers). Use when user runs devflow.auto or asks to deliver end to end from idea to PR automatically without pausing for questions."
argument-hint: "[idea-or-attached-context] [--app <name>] [--beautify]"
disable-model-invocation: true
---


# Skill: devflow.auto

## Quick Start

Run `/devflow-auto <idea> [--app <name>] [--beautify]`.

- `devflow.run` with the `task → pr` preset: `task → plan → implement → test → ship → pr`, unattended from raw idea to opened PR
- `--app <name>`: required only when `devflow/config.md` has a `## Apps` table (monorepo)
- `--beautify`: adds the beautify step (certain improvements only) between implement and test — off by default: ship's `code-reviewer` covers readability and conventions, and run mode never applies opinable proposals

## Purpose

End-to-end autonomous delivery from raw idea to opened PR. Same contract as `devflow.run` (`$HOME/.gemini/antigravity-cli/plugins/devflow/references/run-mode.md`, `auto` column) — extended upstream (task, plan) and downstream (ship → pr). Halts only on major discrepancies; minor ones become decision flags surfaced in the PR body.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- Idea maps to existing/planned feature in `docs/product.md` — `task.md` exists → `devflow.plan` or `devflow.run`
- Idea brainstorm-scale (no concrete problem or user) — `devflow-task` Step 3 routes it away; auto never defaults around it
- User wants step-by-step review — individual commands
- Interrupted run, blocked or corrupted state — `devflow.resume`

## Input contract

Collected **before** arming — no user prompt after Step 0:

- [ ] Idea text (or attached context) in `$ARGUMENTS` — empty → ask
- [ ] No active `.devflow-run.json` — stale → ask user: delete (`run disarm`) or `devflow.resume`
- [ ] Monorepo (`## Apps` table) → `--app` valid, or ask now — never guessed later

Any item fails → stop, report, do not arm.

## Workflow

### Step 0 - Arm

Arm immediately (no confirmation): `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" run arm --orchestrator devflow.auto --from task --until pr` (`feature: null`, grader cap 2; exit 2 = stale marker → stop, ask). Announce: `🤖 devflow.auto: task → plan → implement → [beautify →] test → ship → pr (unattended; halts only on major discrepancies)`.

### Step 1 - Chain

Every step: full skill workflow, run-mode clauses active, status boundaries written. Stop/continue per **Discrepancy classes** in `run-mode.md`. Steps up to test run in `step-runner` subagents per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/run-mode.md` → **Step dispatch** (groups for `devflow.auto`); ship and pr run here.

1. `devflow-task` (arguments: the idea text, `--app`) → `devflow-plan` — **one** step-runner (group `task → plan`, feature `none yet`; the runner sets `run feature` after task). Plan Step 5b consistency check always runs: Critical → stop; Required → plan fix or waiver flag. Feature for the next dispatch = the `feature:` field of its `RESULT:` line.
2. Middle pipeline — `devflow-run` Step 1 chain rules, `--from implement --until ship`: implement → (beautify, only with `--beautify`) → test (incl. Step 6b) dispatched, then `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-ship/SKILL.md` here.
3. Ship gate passes (or loop cap reached with exceptions flagged) → `devflow-ship` Step 5 executes `$HOME/.gemini/antigravity-cli/plugins/devflow/skills/devflow-pr/SKILL.md`; PR body carries `## Autonomous Decisions & Discrepancies` from `## Decision flags`, `## Deviations`, `task.md` `## Assumptions & Risks`.

### Step 2 - Disarm + report

Disarm on every exit path: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" run disarm`. Then `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" report` (computed Feature, Files, Checks, Verification, Flags lines — paste as printed; skip when no `task.md` was written). Report:

```text
🤖 devflow.auto [complete: idea → PR opened | stopped at <step>: <major discrepancy>]

Branch:        [type]/[NNN]_[feature-name]   PR: [URL, when opened]
Steps:         task · plan · implement · [beautify] · test · ship · pr  [✅/⏭/❌ each]
[report lines, as printed]
[Blocker + action required, when stopped — continue with devflow.resume or interactive commands]
```

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Asking the user mid-chain | Collect idea/app/stale-marker decisions before Step 0 |
| Silent defaults | Every autonomous choice → `## Decision flags` → PR body |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/references/run-mode.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/state-machine.md` (handoff format), `$HOME/.gemini/antigravity-cli/plugins/devflow/references/escalation-ladder.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md` |
| Executes | `devflow-task` → `devflow-plan` (one step-runner), then `devflow-run` chain (`devflow-implement`, `devflow-beautify` with `--beautify`, `devflow-test`, `devflow-ship`) → `devflow-pr` |
| Writes | `.devflow-run.json` (armed Step 0, `feature` set by the step-runner after task, deleted Step 2); feature artifacts via chained skills |
| Output | Opened PR with autonomous decisions & discrepancies section |
| Related | `devflow-run` (middle pipeline only), `devflow-resume` |
