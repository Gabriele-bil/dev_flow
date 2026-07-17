---
name: devflow-resume
description: Resumes an interrupted DevFlow session — reads saved state, cross-checks plan.md markers, confirms resume position, re-enters correct pipeline skill. Use when returning after session restart, compaction, or break to continue work where it left off.
argument-hint: []
---

# Skill: devflow.resume

First-class session re-entry. Reads state, validates it against files, routes to the correct pipeline step — no re-deriving from scratch, no re-implementing `[done]` work.

## Purpose

Resume an interrupted pipeline at the exact position it stopped. Promotes the resume logic previously buried in `devflow-implement` Step 1 and `devflow-recovery` to a dedicated entry point.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Pipeline state is corrupted or inconsistent (state says X, files say Y) — use `devflow.recovery`
- User only wants a snapshot of where things stand — use `devflow.status`
- No pipeline was ever started (no `devflow/features/`, no `.devflow-state.json`) — use `devflow.task` or `devflow.setup`
- Starting a new feature — resume continues existing work only

## Input contract

- [ ] `devflow/config.md` exists (adapter known)
- [ ] `.devflow-state.json` exists OR at least one `devflow/features/*/plan.md` exists

Both absent → stop: "Nothing to resume. Start with `/devflow.task` (or `/devflow.setup` on a new project)."

## Workflow

### Step 1 — Read saved state

```bash
cat .devflow-state.json 2>/dev/null || echo "STATE_MISSING"
```

Extract `feature`, `plan_status`, `next_step`, `pending_files`.

If `STATE_MISSING`: derive from files — latest `devflow/features/*/plan.md` (highest `NNN_` prefix), read its `**Status:**`, map to `next_step` via `@devflow/references/state-machine.md` status table. Continue with derived values.

Also read the feature checkpoint when present — restores working context lost at compaction (`slice`, `decisions`, `constraints`, `errors_tried`; schema: `state-machine.md` → **Checkpoint file**):

```bash
cat devflow/features/[NNN]_[feature-name]/.checkpoint.json 2>/dev/null
```

Also read the handoff when present — prose context written under context pressure (schema: `state-machine.md` → **Handoff file**); its **Next action** overrides position guessing:

```bash
cat devflow/features/[NNN]_[feature-name]/handoff.md 2>/dev/null
```

`.devflow-run.json` present (stale run marker from interrupted `devflow.run`): note it for Step 3 — run mode died with its session, never silently re-arm.

### Step 2 — Cross-check state against files

Trust order: `plan.md` > `.devflow-state.json` (state file is derived cache — see `@devflow/references/state-machine.md`).

1. Read `plan.md` `**Status:**` for the active feature.
2. Count `[done]` / `[pending]` markers in **File List**.
3. Validate consistency:

| Check | Inconsistent when | Action |
| --- | --- | --- |
| Status valid | value not in `state-machine.md` table | route `devflow.recovery` |
| Status vs markers | `implemented`+ but `[pending]` entries remain | route `devflow.recovery` (state drift) |
| Status vs state file | `plan_status` in state file ≠ plan.md Status | trust `plan.md`; note drift in Step 3 summary |
| `tested` status | `verification.md` missing or Result FAIL | downgrade resume position to `devflow.test` |

Any route to `devflow.recovery` → stop here, tell user why.

### Step 3 — Confirm resume position

Present, then WAIT for user confirmation:

```text
📍 Resume position

Feature:     [NNN]_[feature-name]
Plan status: [status]  →  next: [next_step]
Progress:    [done]/[total] files done
First pending: [file path, if mid-implement]
Checkpoint:  [slice + last decision + last error tried, if .checkpoint.json present]
Handoff:     [next action from handoff.md, if present]
[Drift note, if state file disagreed with plan.md]
[Stale run marker found — resume interactively (delete .devflow-run.json) or re-arm devflow.run?, if present]

Continue with [next_step]? (yes / no / different step)
```

### Step 4 — Re-enter pipeline skill

On confirmation, execute the skill for `next_step` honoring its input contract:

- `devflow.implement` mid-run: enter at first `[pending]` File List entry. Never re-implement a `[done]` file unless explicitly asked.
- All other steps: run from their Step 0.

After position confirmed: delete consumed `handoff.md` (`rm -f devflow/features/[NNN]_[feature-name]/handoff.md`); delete stale `.devflow-run.json` unless user chose to re-arm via `devflow.run`.

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "State file looks fine, skip the cross-check" | State file is a cache written at compaction — plan.md may have moved since. Cross-check is 2 greps |
| "Faster to re-implement the done files, they're small" | Re-implementing `[done]` work destroys prior review/fixes and wastes the session |
| "Position is obvious, no need to confirm with user" | User may have edited files outside DevFlow between sessions — confirmation catches it |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Resuming from memory of previous session | Read `.devflow-state.json` + `plan.md` fresh at invocation |
| Repairing corrupted state inline | Resume routes; `devflow.recovery` repairs — separate concerns |
| Skipping user confirmation on resume position | Always confirm Step 3 — cheapest wrong-direction insurance |
| Re-running completed pipeline steps "to be safe" | Statuses per `state-machine.md` are authoritative; enter at `next_step` only |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `devflow/features/[NNN]_[feature-name]/plan.md`, `devflow/features/[NNN]_[feature-name]/verification.md` (existence), `devflow/features/[NNN]_[feature-name]/.checkpoint.json` (working context), `devflow/features/[NNN]_[feature-name]/handoff.md` (context-pressure handoff), `.devflow-run.json` (stale-marker check), `devflow/config.md` |
| Reads | `@devflow/references/state-machine.md` — status/transition source of truth |
| Deletes | `handoff.md` (after position confirmed), stale `.devflow-run.json` (unless user re-arms `devflow.run`) |
| Writes | nothing else (routing only) |
| Routes to | pipeline skill matching `next_step` |
| Related | `devflow-status` (snapshot only), `devflow-recovery` (corrupted state) |
