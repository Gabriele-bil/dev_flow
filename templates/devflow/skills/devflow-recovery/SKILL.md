---
name: devflow-recovery
description: Diagnoses and recovers a stuck or corrupted DevFlow pipeline. Use when a pipeline step fails repeatedly, state is inconsistent, or the agent is unsure which step to run next.
argument-hint: []
---

# Skill: devflow-recovery

Pipeline rescue. Diagnoses state, identifies failure point, proposes recovery path — no guessing.

## Purpose

Recover a blocked or corrupted pipeline by reading `.devflow-state.json`, inspecting relevant files, and routing to the correct recovery action.

## When NOT to Use

- Pipeline is not stuck — use `devflow-status` for normal progress check
- Session merely interrupted, state consistent — use `devflow-resume` (recovery repairs, resume re-enters)
- User wants to abandon the feature entirely — `rm -rf devflow/features/[NNN]_*` + state reset, not recovery
- `devflow.setup` never ran — run setup first, no state to recover

## Input contract

- [ ] `.devflow-state.json` exists (or explicitly missing — that is the failure)
- [ ] `devflow/config.md` present (adapter known)
- Failure condition: both files absent → inform user: "DevFlow not initialized. Run `/devflow.setup`"

## Workflow

### Step 1 — Read current state

```bash
cat .devflow-state.json 2>/dev/null || echo "STATE_MISSING"
```

Extract:

- `active_feature` — feature directory name
- `next_step` — last recorded step
- `next_feature_number` — NNN counter

If `STATE_MISSING`: proceed to **Recovery path C**.

### Step 2 — Classify failure

Valid statuses and legal transitions: `@devflow/references/state-machine.md` (authoritative — a status outside its tables is itself corruption).

Determine failure category based on state + file existence:

| Category | Condition | Recovery |
| ---------- | ----------- | ---------- |
| **A — Step failure** | State valid; last step threw error or loop | Re-run step from last checkpoint |
| **B — State drift** | State says step X; feature files indicate step Y | Resync state to match files |
| **C — State missing** | `.devflow-state.json` absent | Infer state from feature files; reconstruct |
| **D — Feature missing** | State references feature that doesn't exist | Reset state; list remaining features |
| **E — Adapter mismatch** | `devflow/config.md` adapter differs from plan requirements | Surface conflict; user decides |

### Step 3 — Diagnose (read, do not modify)

For **Category A or B**: read these files in order:

```bash
# 1. Confirm feature directory exists
ls devflow/features/ 2>/dev/null

# 2. Check task.md
cat devflow/features/${ACTIVE_FEATURE}/task.md 2>/dev/null | head -20

# 3. Check plan.md — look for [done] markers
grep -n "\[done\]\|\[pending\]\|\[blocked\]" devflow/features/${ACTIVE_FEATURE}/plan.md 2>/dev/null

# 4. Check observe log for last tool calls
tail -20 .devflow-observe.jsonl 2>/dev/null | jq -r '.tool_name, .file_path // empty' 2>/dev/null

# 5. Check learnings for known issues
grep -i "error\|fail\|stuck\|issue" .devflow-learnings.jsonl 2>/dev/null | tail -5
```

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
Failure category: [A/B/C/D/E — name]

Diagnosis:
  [1-3 sentences describing what went wrong]

Observe log (last 5 tool calls):
  [summary of recent tool activity]

Recommended recovery:
  Option 1 (recommended): [specific action — e.g. "Re-run devflow.implement from subtask 3"]
  Option 2: [alternative — e.g. "Reset state to devflow.plan and re-plan from scratch"]
  Option 3 (nuclear): [delete feature + start over — only if data loss acceptable]

Waiting for your choice (1/2/3 or describe what you want to do).
```

Wait for user confirmation before executing any recovery action.

### Step 5 — Execute recovery

Execute only the user-chosen option.

**Re-run step** (Option 1 typical):

- Read `plan.md` to find last `[done]` marker
- Continue `devflow.implement` from next pending subtask
- Do not re-run completed subtasks

**Resync state** (Option 2 typical):

```bash
# Reconstruct .devflow-state.json from files
jq -n \
  --arg feature "$ACTIVE_FEATURE" \
  --arg step "$INFERRED_STEP" \
  --argjson num $NNN \
  '{active_feature: $feature, next_step: $step, next_feature_number: $num}' \
  > .devflow-state.json
```

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
| Auto-fix state without diagnosis / re-run from step 1 | Read `.devflow-state.json` + last 20 observe entries first; resume from last `[done]` marker. |
| Auto-execute nuclear reset without user confirmation | Present all options; wait for explicit choice. Nuclear destroys traceability. |
| Use recovery for normal pipeline progression | `devflow-status` first; recovery only when status shows corruption. |
| Ignore `.devflow-observe.jsonl` during diagnosis | Observe log shows exact tool calls before failure — always check it. |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-state.json`, `.devflow-observe.jsonl`, `.devflow-learnings.jsonl` |
| Reads | `devflow/features/*/task.md`, `devflow/features/*/plan.md` |
| Reads | `devflow/config.md`, `@devflow/references/state-machine.md` |
| Writes | `.devflow-state.json` (only on user-confirmed resync) |
| Related | `devflow-status` (non-recovery status check), `devflow-resume` (clean session re-entry), `devflow-discovery` (session orientation) |
| Next step | Whichever pipeline step the recovery routes to |
