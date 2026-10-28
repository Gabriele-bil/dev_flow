---
name: devflow-status
description: Shows current DevFlow pipeline state (read-only) — active feature, plan status, progress, next step, adapter. Supports --json with stable exit codes. Use when the user asks where they are in the pipeline, what to run next, or to show the current state.
argument-hint: "[--json]"
---

# Skill: devflow-status

Pipeline dashboard. Shows current state without advancing the pipeline. `--json` → machine-readable output for CI/scripts.

## Purpose

Emit compact status dashboard. Answers "where am I in the pipeline?" — no step execution, no code changes.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- `devflow.setup` not yet run (no `devflow/config.md`) — inform user, stop
- User wants to advance to next step — redirect to correct command directly
- User wants to continue interrupted work — `devflow.resume` (status is snapshot only)

## Workflow

### Step 0 — Mode

`$ARGUMENTS` contains `--json` → skip Steps 1–3, run the emitter snippet from `@devflow/references/status-schema.md` verbatim, output only the resulting JSON object (no prose, no dashboard), report its exit code (0 = healthy, 1 = no pipeline, 2 = inconsistent state). Otherwise continue below.

### Step 1 — Read pipeline state

Order (plan.md authoritative, state file = derived cache):

1. `devflow/config.md` — absent → Case C. Active adapter (single-app) or `## Apps` table (monorepo)
2. Active feature — resolve per `@devflow/references/state-machine.md` → **Active feature resolution**
3. Resolved feature's `plan.md` — `**Status:**`, `**App:**`, File List `[done]`/`[pending]` progress; no `plan.md` → `task.md` `**Status:**` (next step `devflow.plan`, or `devflow.clarify` when markers open)
4. `.devflow-state.json` — drift check only: its `plan_status` ≠ `plan.md` Status → add `Drift:` line (plan.md wins; `devflow.recovery` resyncs)

Status semantics and next-step mapping: `@devflow/references/state-machine.md` (authoritative). Adapter/app resolution: `@devflow/references/adapter-resolution.md`.

### Step 2 — List active features

Scan `devflow/features/`. For each directory found:

- Extract feature ID and name from directory name (`NNN_name` pattern)
- Check if `plan.md` exists; if yes, read its `Status:` field and (monorepo only) its `App:` field
- Collect list: `[id_name, status, app]` (`app` empty in single-app repos)

### Step 3 — Emit dashboard

**Case A — active feature resolved:**

```text
DevFlow Status

Adapter:     <adapter>
App:         <app>   <!-- monorepo only, omit line in single-app -->
Feature:     <feature>
Plan:        devflow/features/<feature>/plan.md
Status:      <plan_status>  →  next: <next_step>
Drift:       state file says <state_plan_status> — plan.md wins   <!-- only on drift -->
Progress:    <done>/<total> files done (<pending> remaining)
Metrics:     token savings, est. cost, pass@1 → devflow.metrics   <!-- only when .devflow-filter-stats.jsonl or .devflow-metrics.jsonl exists -->
Learnings:   <n> auto-detected (retry loops etc.) · <m> contested instincts — see devflow.learn list

Pending files:
  - <file1>
  - <file2>
  ...

All features:
  <id_name>   [<status>]   [<app>]   <!-- [<app>] tag omitted in single-app -->
  ...

Commands:
  <next_step>  — continue current feature
  devflow.plan  — start planning <next_unstarted_feature>
```

**Case B — no active feature resolved, `devflow/config.md` present:**

```text
DevFlow Status

Adapter: <adapter>   <!-- monorepo: "Apps: <N> configured (web→nextjs, mobile→flutter, …)" instead -->
No open feature (all terminal, blocked, or none yet).

Start a feature: devflow.task   <!-- blocked features listed → devflow.recovery -->
```

**Case C — no `devflow/config.md`:**

```text
DevFlow not configured. Run: /devflow.setup
```

## Metrics pointer (optional)

Savings/cost/pass@1 are owned by `devflow.metrics` — status never recomputes them. `Metrics:` line only when `.devflow-filter-stats.jsonl` or `.devflow-metrics.jsonl` exists; both absent → omit line.

## Learnings line (optional)

`Learnings:` line only when `.devflow-learnings.jsonl` or `.devflow-instincts.yaml` exists. Compute:

```bash
n=$(jq -s 'length' .devflow-learnings.jsonl 2>/dev/null || echo 0)
m=$(yq '[.instincts[]? | select(.contested == true)] | length' .devflow-instincts.yaml 2>/dev/null || echo 0)
```

Both files absent → omit line, zero behavior change. Turns raw JSONL/YAML into a one-line headless summary instead of requiring manual `jq`/`yq` reads — full detail stays in `devflow.learn list`.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Editing `.devflow-state.json` directly | Use `devflow-recovery`; never hand-edit state |
| Prose or dashboard around `--json` output | Single JSON object on stdout — consumers parse it (see `status-schema.md`) |
| Reporting status from memory | Always read `plan.md` at invocation time |
| Reporting state-file status over `plan.md` | `plan.md` authoritative; state file only feeds the Drift line |
| Using status as full routing guide | `references/orientation.md` = routing tree; status = snapshot of active feature |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `devflow/config.md`, `devflow/features/*/plan.md`, `@devflow/references/adapter-resolution.md`, `@devflow/references/state-machine.md`, `@devflow/references/status-schema.md` (`--json` mode) |
| Reads (optional) | `.devflow-filter-stats.jsonl`, `.devflow-metrics.jsonl` — existence only (Metrics pointer line) |
| Reads (optional) | `.devflow-learnings.jsonl`, `.devflow-instincts.yaml` — auto-detected/contested learnings count (Learnings line) |
| Writes | nothing |
| Related | `@devflow/references/orientation.md` (full routing tree), `devflow-resume` (session re-entry), `devflow-recovery` (corrupted state), `devflow-learn` (full learnings detail), `devflow-metrics` (savings, cost, pass@1) |
