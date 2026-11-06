---
name: devflow-resume
description: Resumes an interrupted or stuck DevFlow session — reads saved state, cross-checks plan.md markers, resyncs a drifted state cache, unblocks a blocked plan (user-confirmed), re-enters correct pipeline skill. Use when returning after session restart, compaction, or break, or when a pipeline step is blocked or state looks inconsistent.
argument-hint: "[optional-feature]"
disallowed-tools: Write, Edit, NotebookEdit
---

# Skill: devflow.resume

**Arguments:** `$ARGUMENTS` — empty → resume the feature resolved with `bash "@devflow/scripts/devflow-state.sh" resolve`.

First-class session re-entry. Reads state, validates it against files, routes to the correct pipeline step — no re-deriving from scratch, no re-implementing `[done]` work.

## Purpose

Resume an interrupted or blocked pipeline at the exact position it stopped. Single re-entry point: also repairs state drift (`devflow-state.sh sync`) and unblocks `blocked` plans (user-confirmed reset).

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- User only wants a snapshot of where things stand — use `devflow.status`
- No pipeline was ever started (no `devflow/features/`, no `.devflow-state.json`) — use `devflow.task` or `devflow.setup`
- Starting a new feature — resume continues existing work only

## Input contract

- [ ] `devflow/config.md` exists (adapter known; monorepo: `plan.md`'s App resolves in the `## Apps` table — see `@devflow/references/adapter-resolution.md`)
- [ ] `.devflow-state.json` exists OR at least one `devflow/features/*/plan.md` exists

Both absent → stop: "Nothing to resume. Start with `/devflow.task` (or `/devflow.setup` on a new project)."

## Workflow

### Step 1 — Read saved state

Resolve feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask) (explicit argument → state `.feature // .active_feature` → lowest open feature → ask). Read its `plan.md` `**Status:**`, map to `next_step` via the status table. State file (`plan_status`, `next_step`, `pending_files`) = hint only — Step 2 cross-checks it.

Also read the feature checkpoint when present — restores working context lost at compaction (`slice`, `decisions`, `constraints`, `errors_tried`; schema: `state-machine.md` → **Checkpoint file**):

```bash
cat devflow/features/[NNN]_[feature-name]/.checkpoint.json 2>/dev/null
```

Also read the handoff when present — prose context written under context pressure (schema: `state-machine.md` → **Handoff file**); its **Next action** overrides position guessing:

```bash
cat devflow/features/[NNN]_[feature-name]/handoff.md 2>/dev/null
```

`.devflow-run.json` present (stale run marker from interrupted `devflow.run` or `devflow.auto` — check `from`/`until` to tell which): note it for Step 3 — run mode died with its session, never silently re-arm.

### Step 2 — Cross-check state against files

Trust order: `plan.md` > `.devflow-state.json` (state file is derived cache — see `@devflow/references/state-machine.md`).

1. Read `plan.md` `**Status:**` for the active feature.
2. Count `[done]` / `[pending]` markers in **File List**.
3. Validate consistency:

| Check | Inconsistent when | Action |
| --- | --- | --- |
| Status valid | value not in `state-machine.md` table | Step 2b — propose reset (ask) |
| Status vs markers | `implemented`+ but `[pending]` entries remain | Step 2b — propose reset to `implementing` (ask) |
| Status `blocked` | escalation ladder Level 5 | Step 2b — unblock |
| Status vs state file | state file `plan_status` ≠ plan.md Status, or state file missing/corrupt | trust `plan.md`; `bash "@devflow/scripts/devflow-state.sh" sync [F]` (corrupt → `rm .devflow-state.json` first); note drift in Step 3 |
| `tested` status | `verification.md` missing or Result FAIL | downgrade resume position to `devflow.test` |
| Feature in state file | `devflow/features/<feature>/` absent | `sync` on the resolved feature; note in Step 3 |

### Step 2b — Unblock / reset (user-confirmed)

Only for the ask rows above. Find blocking step — stuck-report (`🛑 BLOCKED: [step]`) in `handoff.md` or recent output, else `.checkpoint.json` `step`, else File List markers — then pick reset status from `state-machine.md` → **Unblock reset table**. Present stuck cause + `errors_tried` + proposed status; WAIT.

- Cause unresolved (same failure reproduces) → no reset; propose re-plan (`devflow.plan`) or `devflow.backprop`; stop.
- Confirmed → `bash "@devflow/scripts/devflow-state.sh" set plan <status> --force [F]` (backward transition, never silent) → continue Step 3 with new `next_step`.

### Step 3 — Confirm resume position

Present, then WAIT for user confirmation:

```text
📍 Resume position

Feature:     [NNN]_[feature-name]
App:         [app]   <!-- monorepo only, from plan.md's App field; omit line in single-app -->
Plan status: [status]  →  next: [next_step]
Progress:    [done]/[total] files done
First pending: [file path, if mid-implement]
Checkpoint:  [slice + last decision + last error tried, if .checkpoint.json present]
Handoff:     [next action from handoff.md, if present]
[Drift note, if state file was resynced] · [Unblocked: blocked → <status>, if Step 2b ran]
[Stale run marker found — resume interactively (delete .devflow-run.json) or re-arm devflow.run / devflow.auto?, if present]

Continue with [next_step]? (yes / no / different step)
```

### Step 4 — Re-enter pipeline skill

On confirmation, execute the skill for `next_step` honoring its input contract:

- `devflow.implement` mid-run (Status `implementing` — accepted by its input contract): enter at first `[pending]` File List entry; no `[pending]` left (interrupted `--fix` re-entry) → ask user for the findings list, re-enter with `--fix`. When slice headings carry `deps:` annotations (`plan-template.md` → **Slice dependency annotations**): enter at the first `[pending]` entry of a slice whose dep slices are all `[done]`; note any blocked slice skipped. Never re-implement a `[done]` file unless explicitly asked.
- Status `implemented`: offer the optional beautify step as `devflow.implement` Step 8 does (`quick`: default no) — yes → `@devflow/skills/devflow-beautify/SKILL.md`, no → `devflow.test`.
- All other steps: run from their Step 0.

After position confirmed: delete consumed `handoff.md` (`rm -f devflow/features/[NNN]_[feature-name]/handoff.md`); delete stale `.devflow-run.json` unless user chose to re-arm via `devflow.run` or `devflow.auto`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Resuming from memory of previous session | Read `.devflow-state.json` + `plan.md` fresh at invocation |
| Re-running completed pipeline steps "to be safe" | Statuses per `state-machine.md` are authoritative; enter at `next_step` only |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `devflow/features/[NNN]_[feature-name]/plan.md`, `devflow/features/[NNN]_[feature-name]/verification.md` (existence), `devflow/features/[NNN]_[feature-name]/.checkpoint.json` (working context), `devflow/features/[NNN]_[feature-name]/handoff.md` (context-pressure handoff), `.devflow-run.json` (stale-marker check), `devflow/config.md`, `@devflow/references/adapter-resolution.md` |
| Reads | `@devflow/references/state-machine.md` — status/transition source of truth |
| Deletes | `handoff.md` (after position confirmed), stale `.devflow-run.json` (unless user re-arms `devflow.run` or `devflow.auto`) |
| Writes | via `devflow-state.sh` only — `sync` (drifted/missing cache), `set plan <status> --force` (Step 2b, user-confirmed) |
| Routes to | pipeline skill matching `next_step` |
| Related | `devflow-status` (snapshot only), `@devflow/references/escalation-ladder.md` (how `blocked` is reached) |
