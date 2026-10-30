---
name: recovery
description: Diagnoses and repairs a stuck, blocked, or corrupted DevFlow pipeline. Use when a pipeline step fails repeatedly, plan.md is blocked, or state files are inconsistent or corrupted.
argument-hint: "[optional-feature]"
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

# Skill: devflow-recovery

**Arguments:** `$ARGUMENTS` — empty → diagnose the feature resolved with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve`, plus every `blocked` feature.

Pipeline rescue. Diagnoses state, identifies failure point, proposes recovery path — no guessing.

## Purpose

Recover a blocked or corrupted pipeline: read `plan.md` (authoritative) + `.devflow-state.json` (cache), inspect files, route to the correct recovery action.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- Pipeline is not stuck — use `devflow-status` for normal progress check
- Session merely interrupted, state consistent — use `devflow-resume` (recovery repairs, resume re-enters)
- User wants to abandon the feature entirely — `rm -rf devflow/features/[NNN]_*` + state reset, not recovery
- `devflow.setup` never ran — run setup first, no state to recover

## Input contract

- [ ] `.devflow-state.json` exists (or explicitly missing — that is the failure)
- [ ] `devflow/config.md` present (adapter known; monorepo: `plan.md`'s App resolves in the `## Apps` table)
- Failure condition: both files absent → inform user: "DevFlow not initialized. Run `/devflow:setup`"

## Workflow

### Step 1 — Read current state

```bash
cat .devflow-state.json 2>/dev/null || echo "STATE_MISSING"
```

Extract:

- `feature` — feature directory name (read `.feature // .active_feature`; legacy alias, never write it)
- `next_step` — last recorded step
- `next_feature_number` — NNN counter

No explicit feature argument → resolve with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" resolve` (exit 1 → ask); also list every feature whose `plan.md` Status is `blocked` (step 3 of that resolution skips them — recovery is where they surface).

If `STATE_MISSING`: proceed to **Recovery path C**.

### Step 2 — Classify failure

Valid statuses and legal transitions: `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` (authoritative — a status outside its tables is itself corruption).

Determine failure category based on state + file existence:

| Category | Condition | Recovery |
| ---------- | ----------- | ---------- |
| **A — Step failure** | State valid; last step threw error or loop | Re-run step from last checkpoint |
| **B — State drift** | State says step X; feature files indicate step Y | Resync state to match files |
| **C — State missing** | `.devflow-state.json` absent | Infer state from feature files; reconstruct |
| **D — Feature missing** | State references feature that doesn't exist | Reset state; list remaining features |
| **E — Adapter mismatch** | `devflow/config.md` adapter differs from plan requirements | Surface conflict; user decides |
| **F — App mismatch** | Monorepo: `plan.md`'s `**App:**` missing, or not a row in `devflow/config.md`'s `## Apps` table | Surface conflict; ask user to pick a valid app or fix `plan.md` |
| **G — Blocked** | `plan.md` `**Status:** blocked` (escalation ladder Level 5) | Show stuck-report; user resolves cause; user-confirmed `plan.md` Status reset (Step 5) |

### Step 3 — Diagnose (read, do not modify)

For **Category A or B**: read these files in order:

```bash
# 1. Confirm feature directory exists
ls devflow/features/ 2>/dev/null

# 2. Check task.md
cat devflow/features/${FEATURE}/task.md 2>/dev/null | head -20

# 3. Check plan.md — look for [done] markers
grep -n "\[done\]\|\[pending\]\|\[blocked\]" devflow/features/${FEATURE}/plan.md 2>/dev/null

# 4. Check observe log for last tool calls
tail -20 .devflow-observe.jsonl 2>/dev/null | jq -r '.tool_name, .file_path // empty' 2>/dev/null

# 5. Check learnings for known issues
grep -i "error\|fail\|stuck\|issue" .devflow-learnings.jsonl 2>/dev/null | tail -5

# 6. Check per-feature checkpoint — decisions + errors already tried
cat devflow/features/${FEATURE}/.checkpoint.json 2>/dev/null
```

Checkpoint present → include `errors_tried` in the diagnosis; never re-propose a fix already listed there. Schema: `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` → **Checkpoint file**.

For **Category G (blocked)**: find blocking step — stuck-report (`🛑 BLOCKED: [step]`) in recent output/handoff, else `.checkpoint.json` `step`, else File List markers. Map to reset status:

| Blocked during | Reset `plan.md` Status to | Resume step |
| --- | --- | --- |
| `devflow.implement` | `implementing` (`ready` when no `[done]` yet) | `devflow.implement` |
| `devflow.beautify` | `implemented` | `devflow.beautify` |
| `devflow.test` | `beautified` (`implemented` on hotfix fast-track) | `devflow.test` |
| `devflow.ship` | `tested` | `devflow.ship` |
| unknown | `[pending]` left → `implementing`; all `[done]` → `implemented` | per status table |

Cause unresolved (same failure reproduces) → do not reset; propose re-plan (`devflow.plan`) or `devflow.backprop`.

For **Category C (state missing)**: infer step from feature files:

```text
task.md exists, plan.md absent     → next_step: devflow.plan
plan.md exists, no [done] markers  → next_step: devflow.implement
plan.md has [done] markers         → next_step: devflow.beautify or later
plan.md **Status:** present        → map via state-machine.md status table
```

### Step 4 — Propose recovery

Present diagnosis and ONE recommended action. Do not auto-execute destructive operations.

```text
DevFlow Recovery Diagnosis
==========================
Active feature: [feature or "unknown"]
Last recorded step: [step or "unknown"]
Failure category: [A/B/C/D/E/F/G — name]

Diagnosis:
  [1-3 sentences describing what went wrong]

Observe log (last 5 tool calls):
  [summary of recent tool activity]

Recommended recovery:
  Option 1 (recommended): [specific action — step from plan.md Status via state-machine.md status table, e.g. "Re-run devflow.test" / "Reset blocked → implementing, re-run devflow.implement from entry 3"]
  Option 2: [alternative — e.g. "Reset state to devflow.plan and re-plan from scratch"]
  Option 3 (nuclear): [delete feature + start over — only if data loss acceptable]

Waiting for your choice (1/2/3 or describe what you want to do).
```

Wait for user confirmation before executing any recovery action.

### Step 5 — Execute recovery

Execute only the user-chosen option.

**Re-run step** (Option 1 typical):

- Step = `next_step` for current `plan.md` Status (`${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` → status table) — not always implement
- `devflow.implement`: continue from first `[pending]` entry; never re-run `[done]` entries (targeted rework → `--fix` re-entry)
- Other steps: run from their Step 0, honoring their input contract

**Unblock** (Category G, after user confirms the reset status from the Step 3 table):

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set plan <confirmed-status> --force` — user-confirmed backward transition, never silent; writes `plan.md` and the state cache.
2. Route to the resume step.

**Resync state** (Option 2 typical):

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" sync [NNN]` — rebuilds `feature`, `plan_status`, `task_status`, `next_step`, `progress`, `next_feature_number` from `plan.md`/`task.md`; unknown keys preserved, legacy `active_feature` dropped.

**Nuclear reset** (Option 3):

```bash
rm .devflow-state.json
# Do NOT delete feature files unless user explicitly confirms
```

Confirm before proceeding: "This will reset pipeline state. Feature files preserved. Continue? (yes/no)"

### Step 6 — Confirm recovery

After execution:

```text
Recovery complete.

Action taken: [what was done]
New state: [next_step now set to X]
Next command: [exact command to continue]
```

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Use recovery for normal pipeline progression | `devflow-status` first; recovery only when status shows corruption or `blocked`. |
| Resyncing only the state file for a `blocked` feature | `plan.md` is authoritative — Category G resets `plan.md` Status (user-confirmed), then state |
| Overwriting `.devflow-state.json` with a fresh object | Merge via snippet — hook/other keys survive |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `.devflow-observe.jsonl`, `.devflow-learnings.jsonl`, `devflow/features/*/.checkpoint.json` |
| Reads | `devflow/features/*/task.md`, `devflow/features/*/plan.md` |
| Reads | `devflow/config.md`, `${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md`, `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` |
| Writes | `.devflow-state.json` (merge, only on user-confirmed resync/unblock); `plan.md` `**Status:**` (Category G only, user-confirmed) |
| Related | `devflow-status` (non-recovery status check), `devflow-resume` (clean session re-entry), `${CLAUDE_PLUGIN_ROOT}/references/orientation.md` (session orientation) |
| Next step | Whichever pipeline step the recovery routes to |
