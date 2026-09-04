---
name: devflow-auto
description: Chains task → plan → analyze → implement as one unattended session starting from a raw feature idea — decision flags instead of pauses, consolidated report, stops before beautify. Use when user runs devflow.auto or asks to go from idea to implemented code autonomously without step gates.
argument-hint: [idea-or-attached-context] [--app <name>]
disable-model-invocation: true
---

# Skill: devflow.auto

## Quick Start

Run `/devflow.auto <idea> [--app <name>]`.

- Fixed chain: `task → plan → analyze → implement` — no `--from`/`--until`, single entry, single exit
- `--app <name>`: required only when `devflow/config.md` has a `## Apps` table (monorepo); omit otherwise

## Purpose

Opt-in gated autonomy from raw idea through implemented code. Execute `task → plan → analyze → implement` as one chained unattended session, then stop with consolidated report. Constitution gates (Critical/Required) and `devflow.analyze` Critical/Required findings stay hard stops; `beautify`/`test`/`ship`/PR stay human — run `devflow.run` or the individual steps after.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Autonomy policy

| Allowed unattended | Never unattended |
| --- | --- |
| Write `task.md` / `plan.md`; pick defensible defaults for clarification questions, feature name, plan open questions | `git commit`, `git push`, open PR |
| Run adapter format/analyze/codegen commands during `implement` | Edit `devflow/config.md`, CI/config files (`pre-config-protect` hook enforces) |
| Update `task.md`/`plan.md` Status, `[done]` markers, `## Notes`, `## Decision flags`, `.checkpoint.json`, `.devflow-state.json` | Bypass Constitution Gate Critical/Required (`devflow-plan` Step 0b) |
| Pick defensible default on ambiguity + log decision flag | Proceed past `devflow.analyze` Critical/Required findings |
| Stop on `escalation-ladder.md` Level 5 block | Guess missing **App** on a monorepo feature — still hard stop |
| Create feature branch per `devflow.implement` Step 3 | Apply beautify improvements — chain stops before `beautify` |

## When NOT to Use

- Idea maps to an existing/planned feature in `docs/product.md` — check first; if `task.md` already exists, run `devflow.plan` directly instead
- Monorepo and target app unknown — resolve `--app` first or expect a hard stop at Step 0
- User wants to review `task.md` or `plan.md` before implementation starts — run `devflow.task` / `devflow.plan` interactively instead
- Idea is brainstorm-scale (no concrete problem or user) — `devflow-task` Step 3 routes this away; `devflow.auto` inherits that stop, never defaults around it
- Interrupted run to continue — `devflow.resume`; corrupted state — `devflow.recovery`

## Input contract

- [ ] Idea text (or attached context) present in `$ARGUMENTS` — empty → stop, ask for the idea
- [ ] No active `.devflow-run.json` (stale marker from crashed run → confirm deletion with user, or route `devflow.recovery`)
- [ ] Monorepo (`config.md` has `## Apps` table) → `--app` resolved or user asked before arming — never guessed

Any item fails → stop, report which check failed, do not arm run mode.

## Workflow

### Step 0 - Arm run mode

Parse `$ARGUMENTS`: idea text + optional `--app`. Present run plan + policy summary, WAIT for single confirmation:

```text
🤖 devflow.auto: task → plan → analyze → implement   (feature number assigned in task step)

Unattended: write task.md/plan.md, pick defensible defaults for clarification/open questions/feature name, write plan-scoped code.
Never unattended: commit, push, PR, config edits, bypassing Constitution or analyze Critical/Required findings.
Ambiguity → defensible default + flag (task.md ## Notes / plan.md ## Decision flags — you review before beautify).

Proceed? (yes / no)
```

On yes: write `.devflow-run.json` per `@devflow/references/state-machine.md` → **Run marker**, with `feature: null`, `from: "task"`, `until: "implement"`; append `.devflow-run.json` to `.gitignore` when `.gitignore` exists and entry missing. Marker presence switches `devflow-task`, `devflow-plan`, and `devflow-implement` to run mode.

### Step 1 - Chain steps

Execute each step skill in order:

1. `@devflow/skills/devflow-task/SKILL.md` — full workflow, run-mode clauses active (Step 4 clarification, Step 6 feature name). Once `task.md` is written (Step 9), update `.devflow-run.json` `feature` field to the new `NNN_feature-name`.
2. `@devflow/skills/devflow-plan/SKILL.md` — full workflow, run-mode clause active for Open questions. Constitution Gate Critical/Required still stops the chain (Step 2 below), never bypassed.
3. `@devflow/skills/devflow-analyze/SKILL.md` — full 5-pass report. Any **Critical** or **Required** finding → stop chain (Step 3), do not start `implement`. Only **Nit** findings or zero findings → continue.
4. `@devflow/skills/devflow-implement/SKILL.md` — full workflow; existing `.devflow-run.json` run-mode clause applies unchanged.

Chain rules:

- Between steps: no user prompt. Record each step's notify block for the Step 3 consolidated report.
- `devflow-task` Step 3's brainstorm-scale routing (idea too vague or multi-directional for a single feature) still applies and still stops the chain — that is a "not a feature yet" signal, not ambiguity to default around.
- Step input contract fails mid-chain (e.g. `devflow-plan`'s draft-with-unresolved-markers check) → stop run, report the failed check; never force a step.
- Failures inside a step follow `@devflow/references/escalation-ladder.md`; Level 5 block → stop run, keep flags, write consolidated report with stuck-report.
- Context pressure (host warning, large plan) → write handoff per `@devflow/references/state-machine.md` → **Handoff file**, stop run, tell user: restart + `devflow.resume`.

### Step 2 - Decision flags (forward-motion)

Same mechanism as `devflow-run` Step 2, applied at two artifact levels:

- Task-level assumptions (clarification questions, feature name) → `task.md` `## Notes`
- Plan-level assumptions (Open questions) → `plan.md` `## Decision flags`

Product rules are never invented: missing behavior with no repo precedent → most conservative behavior (fail closed / no-op) + flag.

Exceptions that hard-stop even in run mode:

- Missing `--app` on a monorepo feature
- Constitution Gate Critical/Required violation (`devflow-plan` Step 0b)
- `devflow-analyze` Critical or Required finding
- `devflow-task` Step 3 brainstorm-scale routing

### Step 3 - Disarm + consolidated report

Delete `.devflow-run.json` on **every** exit path (complete, contract failure, block, handoff). Report:

```text
🤖 devflow.auto complete: task → [last step executed]

Feature:  [NNN]_[feature-name]  ·  Status: [final plan.md Status, or "task only" if stopped early]
Steps:    task [✅/❌] · plan [✅/⏭/❌] · analyze [✅/⏭/❌] · implement [✅/⏭/❌]
Files:    [N] created · [M] modified
Analyze:  [N] Critical · [N] Required · [N] Nit findings
Flags:    [N] decision flags — review task.md ## Notes / plan.md ## Decision flags
[Stopped at [step]: [failed check | Critical/Required block | stuck-report | handoff written], if not complete]

Next (human): devflow.beautify — or devflow.run --from beautify for the rest of the pipeline
```

Always wait for user here.

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Idea is vague but run mode should just guess and go" | Brainstorm-scale idea routes to `ce-brainstorm`/`idea-refine` even in run mode — a default can't invent a missing feature |
| "Analyze found only Required issues, close enough" | Required findings block same as Critical — never proceed past either unattended |
| "User said full auto, so skip the App question too" | App on monorepo never guessed — hard stop regardless of mode; ask upfront or pass `--app` |
| "Constitution Required violation, but time to move fast" | `devflow-plan` already hard-stops on this; `devflow.auto` adds no bypass |
| "Task and plan clarifications are minor, no need to flag" | Every autonomous decision is logged somewhere reviewable — `## Notes` or `## Decision flags` — before implement touches code |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Silent default without a `## Notes`/`## Decision flags` entry | Every autonomous choice → logged, reviewable before `beautify` |
| Proceeding to `implement` after `analyze` reports Critical/Required | Stop chain, write consolidated report, human reviews `plan.md` first |
| Running `devflow.task` + `devflow.plan` + `devflow.implement` separately and calling it equivalent | Use the chain — marker + flags only work end to end |
| Arming run mode with no concrete idea in `$ARGUMENTS` | Input contract fails fast — ask for the idea, do not arm on empty input |
| Continuing chain after `devflow-task` Step 3 routes to brainstorm | That stop is final for this run — no default resolves "no concrete problem" |
| Leaving `.devflow-run.json` after stop | Delete marker on every exit path — stale marker corrupts next session's mode detection |

## I/O Reference

| | |
| --- | --- |
| Reads | `@devflow/skills/devflow-task/SKILL.md`, `devflow-plan/SKILL.md`, `devflow-analyze/SKILL.md`, `devflow-implement/SKILL.md` |
| Reads | `@devflow/references/adapter-resolution.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Reads | `@devflow/references/state-machine.md` (run marker + handoff schemas), `@devflow/references/escalation-ladder.md` (failure bounds) |
| Writes | `.devflow-run.json` — armed Step 0 (`feature: null`), `feature` field updated after `task` step, deleted Step 3 (every exit path) |
| Writes | `devflow/features/[NNN]_[feature-name]/task.md`, `plan.md` — full workflow output, `## Notes`, `## Decision flags` |
| Executes | `devflow-task`, `devflow-plan`, `devflow-analyze`, `devflow-implement` skills in order |
| Next step | `devflow.beautify` (human) — or `devflow.run --from beautify` |
| Related | `devflow-resume` (interrupted run), `devflow-recovery` (stale marker/corrupted state), `devflow-run` (continues pipeline after `implement`) |
