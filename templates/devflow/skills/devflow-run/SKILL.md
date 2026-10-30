---
name: devflow-run
description: "Middle pipeline batch executor: chains implement → beautify → test for an approved plan in one unattended session with a consolidated report; stops before ship. Use when user runs devflow.run or asks to execute the middle pipeline autonomously without pausing at each step gate, or take plan through review and tests."
argument-hint: "[--from implement|beautify|test] [--until beautify|test|ship]"
disable-model-invocation: true
---

# Skill: devflow.run

## Quick Start

Run `/devflow.run [--from implement] [--until test]`.

- Defaults: `--from implement --until test`
- `--from` ∈ `implement` | `beautify` | `test`; `--until` ∈ `beautify` | `test` | `ship`
- `--until ship`: ship fan-out runs, but Critical/Required verdicts and routing to `devflow.pr` stay human

## Purpose

Opt-in gated autonomy. Execute middle pipeline (implement → beautify → test) as one chained unattended session, then stop with consolidated report. Upstream gates (task/plan approval) and downstream gates (ship verdicts, PR) stay human.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Autonomy policy

Run-mode contract (marker, autonomy table `run` column, decision flags, discrepancy classes, disarm): `@devflow/references/run-mode.md`. Commit/push/PR and config edits never unattended here.

## When NOT to Use

- `task.md` / `plan.md` not yet approved — upstream gates are human; run `devflow.task` / `devflow.plan` first
- First feature on unfamiliar stack or low-confidence plan — run steps interactively
- User wants to review each beautify proposal — run `devflow.beautify` directly
- Interrupted run to continue — `devflow.resume`; corrupted state — `devflow.recovery`
- `plan.md` Status already past `--until` step — nothing to chain; `devflow.status`

## Input contract

- [ ] Feature resolved — explicit `NNN_name` argument, else `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask)
- [ ] `task.md` + `plan.md` exist at `devflow/features/[NNN]_[feature-name]/`
- [ ] `plan.md` **Status** satisfies the `--from` step's input contract (`implement` → `ready`; `beautify` → `implemented`; `test` → `beautified` or `implemented`)
- [ ] No active `.devflow-run.json` (stale marker from crashed run → confirm deletion with user, or route `devflow.recovery`)

Any item fails → stop, report which check failed, do not arm run mode.

## Workflow

### Step 0 - Arm run mode

Parse `$ARGUMENTS`; apply defaults. Present run plan + policy summary, WAIT for single confirmation:

```text
🤖 devflow.run: [from] → ... → [until]   (feature [NNN]_[feature-name])

Unattended: write plan-scoped code, adapter commands, status/checkpoints/decision flags.
Never unattended: commit, push, PR, config edits, opinable refactors.
Ambiguity → defensible default + flag in plan.md ## Decision flags (you review before PR).

Proceed? (yes / no)
```

On yes: `bash "@devflow/scripts/devflow-state.sh" run arm --orchestrator devflow.run --from <from> --until <until> --feature <NNN_name>` (exit 2 = stale marker → ask the user: delete or `devflow.recovery`).

### Step 1 - Chain steps

Execute each step skill in order from `--from` to `--until`, honoring each input contract:

1. `@devflow/skills/devflow-implement/SKILL.md` — full workflow
2. `@devflow/skills/devflow-beautify/SKILL.md` — **certain improvements** only; opinable proposals become decision flags, never applied
3. `@devflow/skills/devflow-test/SKILL.md` — full workflow including Step 6b goal-backward verification
4. `@devflow/skills/devflow-ship/SKILL.md` — only with `--until ship`; fan-out + synthesis, never Step 5 route to `devflow.pr`

Chain rules:

- Between steps: no user prompt. Record each step's notify block for the Step 3 consolidated report.
- Step input contract fails mid-chain → stop run (Step 3), report failed check; never force a step.
- Failures inside a step follow `@devflow/references/escalation-ladder.md`; Level 5 block → stop run, keep flags, write consolidated report with stuck-report.
- Context pressure (host warning, >20 files into large plan) → write handoff per `@devflow/references/state-machine.md` → **Handoff file**, stop run, tell user: restart + `devflow.resume`.

### Step 2 - Decision flags (forward-motion)

Never block on ambiguity while armed — defensible default + `plan.md` `## Decision flags` entry, format and precedence per `@devflow/references/run-mode.md` → **Decision flags**. Major discrepancies stop the run per its **Discrepancy classes**.

### Step 3 - Disarm + consolidated report

Disarm on every exit path: `bash "@devflow/scripts/devflow-state.sh" run disarm`. Report:

```text
🤖 devflow.run complete: [from] → [last step executed]

Feature:  [NNN]_[feature-name]  ·  Status: [final plan.md Status]
Steps:    implement [✅/⏭/❌] · beautify [✅/⏭/❌] · test [✅/⏭/❌] [· ship [✅/❌]]
Files:    [N] created · [M] modified
Tests:    [N] passed · [N] failed  ·  Verification: [PASS|FAIL|PARTIAL] [n]/[n] ACs
Flags:    [N] decision flags — review plan.md ## Decision flags
Pending:  [N] beautify proposals not applied (listed as flags)
[Stopped at [step]: [failed check | stuck-report | handoff written], if not complete]

Next (human): devflow.ship — reviews code AND open flags
```

`--until ship` and gate passed: next human step is `devflow.pr`. Always wait for user here.

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "User said run unattended, committing saves them a step" | Commit/push/PR never unattended — policy table; `devflow.pr` is a human gate |
| "This ambiguity is too important to just flag" | Blocked run = zero progress overnight. Conservative default + flag; user overrides before PR |
| "This opinable improvement is obviously right, apply it" | No approval channel in run mode. Certain improvements only; rest = flags |
| "Skip beautify to reach tests faster" | Chain order fixed; every status boundary written — resume and ship depend on them |
| "Marker file is missing but user wanted autonomy earlier" | No marker = interactive rules. Only Step 0 confirmation arms run mode |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Waiting for user at intermediate step gates while run active | Record the step's notify block; continue chain |
| Silent default without flag entry | Every autonomous decision → `plan.md` `## Decision flags` |
| Looping a failing step beyond ladder budget | `escalation-ladder.md` bounds retries; Level 5 → stop run with stuck-report |
| Leaving `.devflow-run.json` after stop | Delete marker on every exit path — stale marker corrupts next session's mode detection |
| Auto-routing to `devflow.pr` after clean ship | Run never crosses the PR boundary; user runs `devflow.pr` |
| Arming run mode from another skill or mid-conversation | Only Step 0, only after explicit user confirmation |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `plan.md`, `@devflow/references/adapter-resolution.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Reads | `@devflow/references/run-mode.md` (run-mode contract), `@devflow/references/state-machine.md` (handoff format), `@devflow/references/escalation-ladder.md` (failure bounds) |
| Writes | `.devflow-run.json` — armed Step 0, deleted Step 3 (every exit path) |
| Writes | `plan.md` — `## Decision flags` entries |
| Executes | `devflow-implement`, `devflow-beautify`, `devflow-test` skills in order (+ `devflow-ship` with `--until ship`) |
| Next step | `devflow.ship` (human) — or `devflow.pr` when `--until ship` passed |
| Related | `devflow-resume` (interrupted run), `devflow-recovery` (stale marker/corrupted state) |
