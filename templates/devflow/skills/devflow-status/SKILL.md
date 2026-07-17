---
name: devflow-status
description: Shows current DevFlow pipeline state — active feature, progress, next step, and adapter. Use when the user asks where they are in the pipeline or what to do next.
argument-hint: []
disable-model-invocation: true
---

# Skill: devflow-status

Pipeline dashboard. Shows current state without advancing the pipeline.

## Purpose

Emit compact status dashboard. Answers "dove sono nel pipeline?" — no step execution, no code changes.

## When NOT to Use

- `devflow.setup` not yet run (no `devflow/config.md`) — inform user, stop
- User wants to advance to next step — redirect to correct command directly
- User wants to continue interrupted work — `devflow.resume` (status is snapshot only)

## Workflow

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

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Editing `.devflow-state.json` directly | Use `devflow-recovery`; never hand-edit state |
| Reporting status from memory | Always read state file at invocation time |
| Using status instead of discovery at session start | Discovery = full orientation + routing; status = snapshot only |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `devflow/config.md`, `devflow/features/*/plan.md`, `@devflow/references/state-machine.md` |
| Writes | nothing |
| Related | `devflow-discovery` (full pipeline orientation), `devflow-resume` (session re-entry), `devflow-recovery` (corrupted state) |
