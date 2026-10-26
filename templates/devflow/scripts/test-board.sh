#!/bin/bash
# test-board.sh — Behavioral tests for board.sh, devflow-board HTML generation,
# --sync idempotency, DAG critical path, and command timing telemetry hooks.
# Usage: bash templates/devflow/scripts/test-board.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOARD_SH="$SCRIPT_DIR/board.sh"
TEMPLATE_HTML="$PLUGIN_ROOT/skills/devflow-board/assets/board-template.html"
HOOKS_DIR="$PLUGIN_ROOT/hooks"

PASS=0
FAIL=0
ORIG_DIR="$PWD"
T=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

assert_equals() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle" 2>/dev/null; then
    pass "$label"
  else
    fail "$label" "'$needle' not found"
  fi
}

setup() {
  T=$(mktemp -d)
  cd "$T" || exit 1
}

teardown() {
  local tmp="$T"
  cd "$ORIG_DIR"
  rm -rf "$tmp"
  T=""
}

echo "board.sh & devflow-board unit tests"
echo "───────────────────────────────────"

# T1: Empty workspace initializes deterministic index.html and board-data.js cleanly
setup
DEVFLOW_WORKSPACE_ROOT="$T" bash "$BOARD_SH" >/dev/null
if [ -f "$T/devflow/board/index.html" ] && [ -f "$T/devflow/board/board-data.js" ] && [ -f "$T/devflow/board/board-data.json" ]; then
  pass "T1: initializes index.html, board-data.js, and board-data.json in empty workspace"
else
  fail "T1: initializes index.html, board-data.js, and board-data.json in empty workspace" "missing board files"
fi
if cmp -s "$TEMPLATE_HTML" "$T/devflow/board/index.html"; then
  pass "T1b: index.html is byte-identical to canonical board-template.html"
else
  fail "T1b: index.html is byte-identical to canonical board-template.html" "files differ"
fi
assert_equals "T1c: empty workspace has 0 tasks" "$(jq -r '.project.total_tasks' "$T/devflow/board/board-data.json")" "0"
assert_equals "T1d: read_only flag is true" "$(jq -r '.read_only' "$T/devflow/board/board-data.json")" "true"
teardown

# T2: Multi-task Kanban classification, Blockers/Unlocks DAG, Critical Path & Lead Time
setup
mkdir -p "$T/devflow/features/001_foundation" "$T/devflow/features/002_api-service" "$T/devflow/features/003_ui-dashboard" "$T/docs/adr"
cat > "$T/.devflow-state.json" <<'JSON'
{
  "active_feature": "002_api-service",
  "next_step": "devflow.implement",
  "next_feature_number": "004"
}
JSON

cat > "$T/docs/adr/ADR-001-initial-architecture.md" <<'MD'
# ADR-001: Initial Architecture
**Status:** Accepted
Use layered clean architecture.
MD

cat > "$T/devflow/features/001_foundation/task.md" <<'MD'
# Task - Core Foundation Contracts

**ID:** TASK-001
**Date:** 2026-10-20
**Status:** done
**Branch:** feat/001_foundation
**ADRs:** docs/adr/ADR-001-initial-architecture.md
**Blockers:** none
**Unlocks:** TASK-002

---

## Acceptance Criteria
- [x] **AC-1 (UC-1):** GIVEN core setup WHEN initialized THEN contracts compile
MD

cat > "$T/devflow/features/001_foundation/plan.md" <<'MD'
# Plan - Core Foundation Contracts

**ID:** PLAN-001
**Status:** pr-opened
**Complexity:** 5 (quick)

### 001. `src/core.ts` - create [done]
### 002. `src/index.ts` - create [done]
MD

cat > "$T/devflow/features/002_api-service/task.md" <<'MD'
# Task - API Service Layer

**ID:** TASK-002
**Date:** 2026-10-22
**Status:** clarified
**Branch:** feat/002_api-service
**Blockers:** TASK-001
**Unlocks:** TASK-003
MD

cat > "$T/devflow/features/002_api-service/plan.md" <<'MD'
# Plan - API Service Layer

**ID:** PLAN-002
**Status:** implementing
**Complexity:** 10 (standard)

### 001. `src/api.ts` - create [done]
### 002. `src/routes.ts` - create [pending]
MD

cat > "$T/devflow/features/003_ui-dashboard/task.md" <<'MD'
# Task - UI Dashboard

**ID:** TASK-003
**Date:** 2026-10-25
**Status:** draft
**Branch:** feat/003_ui-dashboard
**Blockers:** TASK-002
**Unlocks:** none
MD

cat > "$T/.devflow-timings.jsonl" <<'JSONL'
{"ts":"2026-10-20T09:10:00Z","command":"task","step":"devflow.task","feature":"001_foundation","active_feature":"001_foundation","started_at":"2026-10-20T09:00:00Z","ended_at":"2026-10-20T09:10:00Z","duration_sec":600,"input_tokens":2000,"output_tokens":500,"estimated_cost_usd":0.02}
{"ts":"2026-10-20T09:30:00Z","command":"implement","step":"devflow.implement","feature":"001_foundation","active_feature":"001_foundation","started_at":"2026-10-20T09:15:00Z","ended_at":"2026-10-20T09:30:00Z","duration_sec":900,"input_tokens":5000,"output_tokens":1200,"estimated_cost_usd":0.05}
{"ts":"2026-10-22T10:05:00Z","command":"plan","step":"devflow.plan","feature":"002_api-service","active_feature":"002_api-service","started_at":"2026-10-22T10:00:00Z","ended_at":"2026-10-22T10:05:00Z","duration_sec":300,"input_tokens":3000,"output_tokens":600,"estimated_cost_usd":0.03}
JSONL

DEVFLOW_WORKSPACE_ROOT="$T" bash "$BOARD_SH" >/dev/null
DATA="$T/devflow/board/board-data.json"

assert_equals "T2a: total tasks is 3" "$(jq -r '.project.total_tasks' "$DATA")" "3"
assert_equals "T2b: completed tasks is 1" "$(jq -r '.project.completed_tasks' "$DATA")" "1"
assert_equals "T2c: completion pct is 33" "$(jq -r '.project.completion_pct' "$DATA")" "33"
assert_equals "T2d: TASK-001 column is pr_opened_done" "$(jq -r '.tasks[] | select(.id=="TASK-001") | .column' "$DATA")" "pr_opened_done"
assert_equals "T2e: TASK-002 column is in_progress" "$(jq -r '.tasks[] | select(.id=="TASK-002") | .column' "$DATA")" "in_progress"
assert_equals "T2f: TASK-002 is unblocked (TASK-001 is done)" "$(jq -r '.tasks[] | select(.id=="TASK-002") | .is_blocked' "$DATA")" "false"
assert_equals "T2g: TASK-002 slices progress 1/2 (50%)" "$(jq -r '.tasks[] | select(.id=="TASK-002") | .slices.pct' "$DATA")" "50"
assert_equals "T2h: TASK-003 column is draft_clarified" "$(jq -r '.tasks[] | select(.id=="TASK-003") | .column' "$DATA")" "draft_clarified"
assert_equals "T2i: TASK-003 is blocked (TASK-002 not done)" "$(jq -r '.tasks[] | select(.id=="TASK-003") | .is_blocked' "$DATA")" "true"
assert_equals "T2j: DAG critical path length is 3 (001->002->003)" "$(jq -r '.dag.critical_path | join("->")' "$DATA")" "TASK-001->TASK-002->TASK-003"
assert_equals "T2k: TASK-001 accumulated dev duration is 1500s (600+900)" "$(jq -r '.tasks[] | select(.id=="TASK-001") | .timings.total_duration_sec' "$DATA")" "1500"
assert_equals "T2l: TASK-001 has 2 command timing entries" "$(jq -r '.tasks[] | select(.id=="TASK-001") | .timings.commands | length' "$DATA")" "2"
assert_contains "T2m: TASK-001 Markdown embedded in manifest" "$(jq -r '.tasks[] | select(.id=="TASK-001") | .files.task_md' "$DATA")" "GIVEN core setup"
assert_equals "T2n: ADR-001 parsed into documents.adrs" "$(jq -r '.documents.adrs | length' "$DATA")" "1"

# T3: --sync updates board-data.js without recreating or touching index.html
 sentinel="<!-- IMMUTABLE-SENTINEL-CHECK -->"
printf '\n%s\n' "$sentinel" >> "$T/devflow/board/index.html"
cat > "$T/devflow/features/002_api-service/plan.md" <<'MD'
# Plan - API Service Layer

**ID:** PLAN-002
**Status:** pr-opened
**Complexity:** 10 (standard)

### 001. `src/api.ts` - create [done]
### 002. `src/routes.ts` - create [done]
MD
DEVFLOW_WORKSPACE_ROOT="$T" bash "$BOARD_SH" --sync --quiet
assert_contains "T3a: --sync did not overwrite index.html" "$(cat "$T/devflow/board/index.html")" "$sentinel"
assert_equals "T3b: --sync updated TASK-002 column to pr_opened_done" "$(jq -r '.tasks[] | select(.id=="TASK-002") | .column' "$DATA")" "pr_opened_done"
assert_equals "T3c: --sync unblocked TASK-003 automatically" "$(jq -r '.tasks[] | select(.id=="TASK-003") | .is_blocked' "$DATA")" "false"

# T4: Hook auto-sync via post-task-create.sh when index.html exists
mkdir -p "$T/devflow/features/004_notifications"
cat > "$T/devflow/features/004_notifications/task.md" <<'MD'
# Task - Push Notifications

**ID:** TASK-004
**Date:** 2026-10-26
**Status:** draft
**Branch:** feat/004_notifications
MD
HOOK_PAYLOAD=$(jq -cn --arg fp "$T/devflow/features/004_notifications/task.md" '{tool_use:{name:"Write",input:{file_path:$fp}}}')
(cd "$T" && printf '%s' "$HOOK_PAYLOAD" | bash "$HOOKS_DIR/post-task-create.sh")
assert_equals "T4a: post-task-create.sh auto-synced TASK-004 into board-data.json" "$(jq -r '.project.total_tasks' "$DATA")" "4"
assert_equals "T4b: post-task-create.sh recorded initial task timing entry" "$(jq -r 'select(.active_feature=="004_notifications") | .command' "$T/.devflow-timings.jsonl")" "task"

# T5: planned_ready & implemented_verified columns + post-edit-accumulate.sh sync + error handling
cat > "$T/devflow/features/003_ui-dashboard/plan.md" <<'MD'
# Plan - UI Dashboard
**ID:** PLAN-003
**Status:** ready
**Complexity:** 6 (quick)
MD
cat > "$T/devflow/features/004_notifications/plan.md" <<'MD'
# Plan - Push Notifications
**ID:** PLAN-004
**Status:** tested
**Complexity:** 7 (standard)
MD
EDIT_PAYLOAD=$(jq -cn --arg fp "$T/devflow/features/004_notifications/plan.md" '{tool_use:{name:"Write",input:{file_path:$fp}}}')
(cd "$T" && printf '%s' "$EDIT_PAYLOAD" | bash "$HOOKS_DIR/post-edit-accumulate.sh")
assert_equals "T5a: post-edit-accumulate.sh synced TASK-003 as planned_ready" "$(jq -r '.tasks[] | select(.id=="TASK-003") | .column' "$DATA")" "planned_ready"
assert_equals "T5b: post-edit-accumulate.sh synced TASK-004 as implemented_verified" "$(jq -r '.tasks[] | select(.id=="TASK-004") | .column' "$DATA")" "implemented_verified"
if DEVFLOW_WORKSPACE_ROOT="$T" bash "$BOARD_SH" --port invalid_port >/dev/null 2>&1; then
  fail "T5c: invalid --port exits non-zero" "expected non-zero exit"
else
  pass "T5c: invalid --port exits non-zero"
fi

teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
