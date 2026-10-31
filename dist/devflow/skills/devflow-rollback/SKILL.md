---
name: rollback
description: "Roll back the active DevFlow step (implement or beautify) to its pre-step checkpoint without corrupting pipeline state. Use when user runs devflow.rollback, wants to undo an implementation or beautification, or revert an agent hallucination."
argument-hint: "[--to <step>] [--force]"
disable-model-invocation: true
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

# Skill: devflow.rollback

**Arguments:** `$ARGUMENTS` — empty → roll back the active feature's last step (skill Step 1 defaults).

Reverts the active DevFlow step to its clean pre-step checkpoint, restoring code and state machine synchronization.

## Purpose

Safely discard unwanted changes made during `devflow.implement` or `devflow.beautify` when code generation diverged, introduced hallucinated dependencies, or broke tests beyond immediate repair. Restores code to the pre-step git checkpoint and updates `plan.md` and `.devflow-state.json` to the preceding valid state.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`
- **state-safety** — git reset alone corrupts pipeline state; rollback atomically updates git files, `plan.md` status, and `.devflow-state.json`
- **explicit-confirmation** — destructive operations warn before discarding edits unless `--force` is provided

## When NOT to Use

- Pipeline state is stuck due to environment issues — use `devflow.recovery`
- You want to resume interrupted work where it left off — use `devflow.resume`
- You want to trace a failing test back to acceptance criteria — use `devflow.backprop`

## Workflow

### Step 1 - Resolve Active Feature and Target Step

1. Resolve feature with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask); read current Status from its `plan.md` (authoritative — never from the state file).
2. Determine target rollback destination:
   - If `$ARGUMENTS` contains `--to <step>`: use the specified step (`implement` or `beautify`).
   - If unspecified:
     - Current status is `implementing` or `implemented` → roll back to `ready` (pre-implement).
     - Current status is `beautified` → roll back to `implemented` (pre-beautify).
     - Other statuses → report that rollback is only supported for implement and beautify steps; suggest `devflow.recovery`.

### Step 2 - Locate Pre-Step Git Checkpoint

1. Look for git checkpoint tag on the current branch:
   - Tag format: `devflow-checkpoint/<branch>/<step>` or `refs/tags/devflow-checkpoint/*`.
2. If checkpoint tag exists:
   - Confirm target commit SHA: `git rev-parse "$TAG"`.
3. If checkpoint tag does not exist:
   - Find the commit immediately preceding the feature's first implementation commit, or check `git log -n 5`.
   - Identify the clean base commit before the target step started.

### Step 3 - Execute Rollback

1. Execute clean reset of application code:

   ```bash
   # Reset tracked application files to checkpoint commit
   git reset --hard "$CHECKPOINT_SHA"
   ```

2. Re-verify DevFlow artifacts:
   - Ensure `devflow/features/[NNN]_[name]/task.md` and `plan.md` are preserved.
   - If rolling back from `implement`:
     - In `plan.md`: replace all `- [x] \` or `### [done]` markers in `## File List` with `### [pending]`.
     - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set plan ready`.
   - If rolling back from `beautify`:
     - `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set plan implemented`.
3. Remove stale `.checkpoint.json` and `.handoff.md` from the feature directory if present:

   ```bash
   rm -f "devflow/features/[NNN]_[name]/.checkpoint.json"
   rm -f "devflow/features/[NNN]_[name]/handoff.md"
   ```

### Step 4 - Emit Rollback Summary

Print a concise status update:

```text
↺ Rollback complete

Feature:     [NNN]_[name]
Rolled back: [implement|beautify]
Reset to:    [commit SHA or tag]
Plan status: [ready|implemented]
Next step:   [devflow.implement|devflow.beautify]
```

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Deleting `task.md` or `plan.md` during rollback | Rollback only touches code files and status markers; specifications are preserved. |
| Rolling back committed PRs | Rollback is strictly for local in-progress feature branches before `devflow.pr`. |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `devflow/features/[NNN]_[name]/plan.md`, git tags (`devflow-checkpoint/*`) |
| Writes | `devflow/features/[NNN]_[name]/plan.md` (`Status:` and `[pending]` markers), `.devflow-state.json` |
| Side effects | Discards uncommitted or step-specific git changes back to checkpoint commit |
| Next step | Re-run the rolled back step (`devflow.implement` or `devflow.beautify`) with corrected context |
