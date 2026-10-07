---
name: devflow-auto
description: "Full-cycle autonomous delivery: turns a raw feature idea directly into an opened pull request via task, plan, analyze, implement, beautify, test, ship, and pr. Operates in total autonomy, choosing defensible defaults and documenting minor discrepancies in the pull request; halts only on major discrepancies (Critical blockers). Use when user runs devflow.auto or asks to deliver end to end from idea to PR automatically without pausing for questions."
argument-hint: "[idea-or-attached-context] [--app <name>]"
disable-model-invocation: true
context: fork
agent: general-purpose
background: true
---

# Skill: devflow.auto

## Quick Start

Run `/devflow.auto <idea> [--app <name>]`.

- Full autonomous chain: `task → plan → analyze → implement → beautify → test → ship → pr` — single command, zero intermediate manual pauses, runs unattended from raw idea through an opened PR
- `--app <name>`: required only when `devflow/config.md` has a `## Apps` table (monorepo); omit otherwise

## Purpose

End-to-end autonomous delivery from raw feature idea through an opened pull request. Executes `task → plan → analyze → implement → beautify → test → ship → pr` in one continuous, unattended session.

Once the command is executed, it progresses automatically through the entire flow. It halts ONLY when encountering major discrepancies (Constitution Gate Critical violations, unresolvable Critical analyze contradictions, Level 5 test/build failures, or Critical ship blockers). Any minor discrepancies, ambiguities, defensible assumptions, or non-critical review findings do NOT pause the pipeline: they are resolved via defensible defaults, logged in `plan.md ## Decision flags`, and surfaced prominently in the Pull Request description (`## Autonomous Decisions & Discrepancies`) for human review.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` generated and verified
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **autonomous forward-motion** — never block on minor ambiguities or non-critical findings; pick defensible defaults, record discrepancies in PR
- **fail only on major discrepancies** — hard-stop strictly on Critical blockers (security violations, unresolvable test/build failures)
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Autonomy policy

| Allowed unattended | Never unattended (Hard stops on major discrepancies) |
| --- | --- |
| Write `task.md` / `plan.md`; pick defensible defaults for clarification questions, feature name, plan open questions | Bypass Constitution Gate Critical/Required (`devflow-plan` Step 0b) |
| Run adapter format/analyze/codegen/test commands | Proceed past `devflow.analyze` **Critical** findings |
| Update `task.md`/`plan.md` Status, `[done]` markers, `## Notes`, `## Decision flags`, `.checkpoint.json`, `.devflow-state.json` | Proceed past `devflow.ship` **Critical** blockers |
| Pick defensible default on ambiguity + log decision flag | Exceed `escalation-ladder.md` Level 5 block (failing tests after retries) |
| Create feature branch per `devflow.implement` Step 3 | Guess missing **App** on a monorepo feature |
| Apply `beautify` certain improvements; opinable proposals logged to decision flags | Ignore `devflow-task` Step 3 brainstorm-scale routing (no concrete feature) |
| Run full test suite & goal-backward verification | Edit `devflow/config.md`, CI/config files (`pre-config-protect` hook enforces) |
| Run `ship` multi-agent review fan-out + autonomous grader loop | |
| Record minor discrepancies & review findings in PR description | |
| `git commit`, `git push`, open PR via `gh pr create` | |

## When NOT to Use

- Idea maps to an existing/planned feature in `docs/product.md` — check first; if `task.md` already exists, run `devflow.plan` or `devflow.run`
- Monorepo and target app unknown — resolve `--app` first or expect a hard stop at Step 0
- Idea is brainstorm-scale (no concrete problem or user) — `devflow-task` Step 3 routes this away; `devflow.auto` inherits that stop, never defaults around it
- User explicitly requests interactive step-by-step review at each phase — use individual commands (`devflow.task`, `devflow.plan`, etc.)
- Interrupted run to continue — `devflow.resume`; corrupted state — `devflow.recovery`

## Input contract

- [ ] Idea text (or attached context) present in `$ARGUMENTS` — empty → stop, ask user for the feature idea
- [ ] No active `.devflow-run.json` (stale marker from crashed run → confirm deletion with user, or route `devflow.recovery`)
- [ ] Monorepo (`config.md` has `## Apps` table) → `--app` resolved or user asked before arming — never guessed

Any item fails → stop, report which check failed, do not arm run mode.

## Workflow

### Step 0 - Arm run mode & launch immediately

Parse `$ARGUMENTS`: idea text + optional `--app`.
Once invoked with the feature idea, **do not pause or wait for interactive confirmation**: arm run mode immediately and begin the autonomous pipeline!

Write `.devflow-run.json` per `@devflow/references/state-machine.md` → **Run marker**:
```json
{
  "active": true,
  "feature": null,
  "from": "task",
  "until": "pr",
  "orchestrator": "devflow.auto",
  "started_at": "[ISO-8601 timestamp]",
  "ship_grader_iterations": 2,
  "ship_grader_iteration_count": 0
}
```
Append `.devflow-run.json` to `.gitignore` when `.gitignore` exists and entry missing.
Marker presence switches pipeline step skills to run mode (autonomous defaults, decision flags, no intermediate waits).

Announce start:
```text
🤖 devflow.auto: starting autonomous flow
Pipeline: task → plan → analyze → implement → beautify → test → ship → pr
Mode: Unattended to PR · Minor discrepancies → logged in PR · Halts only on major blockers
```

### Step 1 - Chain steps

Execute each step skill in order through to completion:

1. `@devflow/skills/devflow-task/SKILL.md` — full workflow, run-mode clauses active:
   - Ambiguities/clarifications: pick defensible default (repo precedent > `docs/product.md` > conservative reading), record each in `task.md ## Assumptions & Risks` and `## Notes`. Never leave raw `[NEEDS CLARIFICATION]` marker.
   - Feature naming: pick first proposed name, record alternatives in `## Notes`.
   - Brainstorm routing: if idea has no concrete problem/user, halt (major discrepancy).
   - Once `task.md` is written (Step 9), update `.devflow-run.json` `feature` field to `NNN_feature-name`.
2. `@devflow/skills/devflow-plan/SKILL.md` — full workflow, run-mode clause active:
   - Genuine open questions: pick defensible default (repo precedent > `constitution.md` > adapter convention), append to `plan.md ## Decision flags`.
   - Constitution Gate Critical/Required: if Critical constitution violation occurs, halt (major discrepancy).
3. `@devflow/skills/devflow-analyze/SKILL.md` — full structural analysis:
   - Any **Critical** finding (fundamental contradiction or unresolvable architectural clash) → stop chain (major discrepancy).
   - Any **Required** finding or **Nit** (minor discrepancy or coverage gap) → do NOT stop; apply defensible plan adjustment or log as an autonomous decision/waiver in `plan.md ## Decision flags` to be documented in the PR; proceed to `implement`.
4. `@devflow/skills/devflow-implement/SKILL.md` — full workflow:
   - Create feature branch.
   - Implement vertical slices.
   - Ambiguities: defensible default + `plan.md ## Decision flags`.
   - If Level 5 escalation block hit (unresolvable compile/build failure) → stop run (major discrepancy).
5. `@devflow/skills/devflow-beautify/SKILL.md`:
   - Apply certain improvements; opinable proposals become decision flags in `plan.md ## Decision flags`.
   - Run adapter format and analyze/typecheck.
6. `@devflow/skills/devflow-test/SKILL.md`:
   - Run tests + goal-backward verification (Step 6b).
   - If tests fail after retry budget (Level 5) → stop run (major discrepancy).
   - On pass → continue automatically to `devflow.ship`.
7. `@devflow/skills/devflow-ship/SKILL.md`:
   - Multi-agent review fan-out per depth profile (`code-reviewer`, `security-auditor`, `test-engineer`, etc.).
   - Synthesize report.
   - Any **Critical** issue → stop run (major discrepancy).
   - **Required-only** findings → autonomous grader loop (Step 4b). If still unresolved after iteration limit, document as exceptions in `plan.md ## Decision flags` and proceed.
   - Gate passes → status updated to `shipped`, continue automatically to `devflow.pr`.
8. `@devflow/skills/devflow-pr/SKILL.md`:
   - Run pre-push verification.
   - Commit changes, push branch, open pull request via `gh pr create`.
   - Include the dedicated `## Autonomous Decisions & Discrepancies` section in the PR description, detailing all assumptions, decision flags, minor discrepancies, and non-critical review findings.

Chain rules:
- Between steps: zero user prompts. Forward motion is continuous.
- Context pressure (host warning, large plan) → write handoff per `@devflow/references/state-machine.md` → **Handoff file**, stop run, notify user to restart + `devflow.resume`.

### Step 2 - Discrepancy & Decision flag policy

Autonomous delivery relies on a strict distinction:

#### Major Discrepancies (Hard Stops — Halts execution)
The pipeline halts immediately and alerts the user ONLY on major discrepancies:
1. **Constitution Gate Critical violation** (`devflow-plan` Step 0b) — cannot proceed against foundational project constraints.
2. **`devflow.analyze` Critical finding** — direct contradiction to an accepted ADR or fatal flaw rendering implementation impossible.
3. **`escalation-ladder.md` Level 5 block** — tests failing or code broken after max retries.
4. **`devflow.ship` Critical blocker** — severe security flaw, data corruption risk, or broken build identified by reviewers.
5. **Missing monorepo `--app`** — impossible to determine target app without user input.
6. **Brainstorm-scale idea** — raw idea lacks a concrete feature or user.

#### Minor Discrepancies (Document in PR & Proceed)
Any other discrepancy, ambiguity, or non-critical finding does NOT stop the pipeline:
- Unspecified UI layout, edge case behaviors, or parameter choices: pick defensible default based on repo precedent > constitution > adapter convention.
- Discrepancies between initial idea and actual codebase constraints: adapt plan to reality, log the deviation in `plan.md ## Deviations` and `## Decision flags`.
- `devflow.analyze` Required findings / Nits: document waiver in `plan.md ## Decision flags`.
- `devflow.ship` Required exceptions or Nits: document in `plan.md ## Decision flags`.
- All collected flags and discrepancies are injected into the PR description under `## Autonomous Decisions & Discrepancies`.

### Step 3 - Disarm + Consolidated report

Delete `.devflow-run.json` on **every** exit path (complete, blocker, handoff).

When PR is opened successfully:
```text
🤖 devflow.auto complete: idea → PR opened!

Feature:  [NNN]_[feature-name]  ·  Status: pr-opened
Branch:   [type]/[NNN]-[feature-name]
PR Link:  [PR URL returned by gh CLI]
Steps:    task [✅] · plan [✅] · analyze [✅] · implement [✅] · beautify [✅] · test [✅] · ship [✅] · pr [✅]
Files:    [N] created · [M] modified
Tests:    [N] passed · Verification: PASS [n]/[n] ACs
Discrepancies & Flags: [N] documented in PR body (see "Autonomous Decisions & Discrepancies")

Pipeline finished in total autonomy. Review the PR link above!
```

When stopped at a major discrepancy:
```text
🚨 devflow.auto stopped at [step]: [Major Discrepancy Description]

Feature:  [NNN]_[feature-name]  ·  Status: [plan.md Status or "task only"]
Blocker:  [Critical issue details]
Flags:    [N] decision flags recorded so far

Action required: Resolve the critical discrepancy above, then continue with devflow.resume or interactive commands.
```

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Idea has ambiguity, I should pause and ask the user" | devflow.auto operates in total autonomy — pick defensible default, log to notes/PR |
| "I should stop before beautify or PR for safety" | devflow.auto delivers end-to-end all the way to PR; human reviews everything on GitHub |
| "Analyze reported a Required finding, I should stop" | Only Critical findings halt devflow.auto; Required findings are resolved or logged to PR |
| "Ship review had minor notes, I should ask before PR" | Minor notes and exceptions are documented in the PR description, not reasons to stop |
| "Constitution Critical violation, but I should auto-proceed" | Critical violations are major discrepancies that always hard-stop |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Pausing for user confirmation at Step 0 when idea is given | Proceed immediately into the pipeline |
| Pausing at intermediate step gates | Chain continuously without user prompts |
| Stopping before beautify, test, ship, or PR | Execute the full pipeline through `gh pr create` |
| Proceeding on Critical analyze/ship/constitution blockers | Critical = major discrepancy = hard stop |
| Silent defaults without documenting in PR | Every autonomous choice → `plan.md ## Decision flags` → PR description |
| Leaving `.devflow-run.json` after exit | Delete marker on every exit path |

## I/O Reference

| | |
| --- | --- |
| Reads | `@devflow/skills/devflow-task/SKILL.md`, `devflow-plan/SKILL.md`, `devflow-analyze/SKILL.md`, `devflow-implement/SKILL.md`, `devflow-beautify/SKILL.md`, `devflow-test/SKILL.md`, `devflow-ship/SKILL.md`, `devflow-pr/SKILL.md` |
| Reads | `@devflow/references/adapter-resolution.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Reads | `@devflow/references/state-machine.md` (run marker + handoff schemas), `@devflow/references/escalation-ladder.md` (failure bounds) |
| Writes | `.devflow-run.json` — armed Step 0 (`feature: null`, `from: "task"`, `until: "pr"`), `feature` field updated after `task` step, deleted Step 3 |
| Writes | `devflow/features/[NNN]_[feature-name]/task.md`, `plan.md` — full workflow output, `## Notes`, `## Decision flags` |
| Executes | `devflow-task`, `devflow-plan`, `devflow-analyze`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-ship`, `devflow-pr` skills in order |
| Output | Open Pull Request on GitHub with full autonomous report and discrepancies |
| Related | `devflow-resume` (interrupted run), `devflow-recovery` (stale marker/corrupted state), `devflow-run` (middle pipeline batch runner) |
