---
name: devflow-status
description: Shows current DevFlow pipeline state — active feature, progress, next step, and adapter. Supports --json for machine-readable output with stable exit codes. Use when the user asks where they are in the pipeline or what to do next.
argument-hint: [--json]
disable-model-invocation: true
---

# Skill: devflow-status

Pipeline dashboard. Shows current state without advancing the pipeline. `--json` → machine-readable output for CI/scripts.

## Purpose

Emit compact status dashboard. Answers "dove sono nel pipeline?" — no step execution, no code changes.

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

Priority order:

1. `.devflow-state.json` in CWD — most recent state, saved by pre-compact hook
2. `devflow/config.md` — active adapter
3. `devflow/features/*/plan.md` — find most recent via `ls -t`; parse progress from plan if `.devflow-state.json` absent

Status semantics and next-step mapping: `@devflow/references/state-machine.md` (authoritative).

### Step 2 — List active features

Scan `devflow/features/`. For each directory found:

- Extract feature ID and name from directory name (`NNN_name` pattern)
- Check if `plan.md` exists; if yes, read its `Status:` field
- Collect list: `[id_name, status]`

### Step 3 — Emit dashboard

**Case A — `.devflow-state.json` present:**

```text
DevFlow Status

Adapter:     <adapter>
Feature:     <feature>
Plan:        <plan_path>
Status:      <plan_status>  →  next: <next_step>
Progress:    <done>/<total> files done (<pending> remaining)
Savings:     output filter kept <kept_chars> of <raw_chars> chars over <n> cmds (~<pct>% saved)

Pending files:
  - <file1>
  - <file2>
  ...

All features:
  <id_name>   [<status>]
  ...

Commands:
  <next_step>  — continue current feature
  devflow.plan  — start planning <next_unstarted_feature>
```

**Case B — no `.devflow-state.json`, but `devflow/config.md` present:**

```text
DevFlow Status

Adapter: <adapter>
No active pipeline session found.

Start a feature: devflow.task
```

**Case C — no `devflow/config.md`:**

```text
DevFlow not configured. Run: /devflow.setup
```

## Filter savings line (optional)

`Savings:` line only when `.devflow-filter-stats.jsonl` exists in consumer root (written by `post-bash-output-filter.sh`, one JSONL entry per filtered command). Compute:

```bash
jq -s '{n:length, raw:(map(.raw_chars)|add), kept:(map(.kept_chars)|add)}' .devflow-filter-stats.jsonl
```

`pct = 100 * (1 - kept/raw)`, rounded. File absent → omit line, zero behavior change. Measured local data — use to accept/reject filter tuning (thresholds, command classes) instead of upstream claims.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Editing `.devflow-state.json` directly | Use `devflow-recovery`; never hand-edit state |
| Prose or dashboard around `--json` output | Single JSON object on stdout — consumers parse it (see `status-schema.md`) |
| Reporting status from memory | Always read state file at invocation time |
| Using status instead of discovery at session start | Discovery = full orientation + routing; status = snapshot only |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `devflow/config.md`, `devflow/features/*/plan.md`, `@devflow/references/state-machine.md`, `@devflow/references/status-schema.md` (`--json` mode) |
| Reads (optional) | `.devflow-filter-stats.jsonl` — filter savings telemetry (Savings line) |
| Writes | nothing |
| Related | `devflow-discovery` (full pipeline orientation), `devflow-resume` (session re-entry), `devflow-recovery` (corrupted state) |
