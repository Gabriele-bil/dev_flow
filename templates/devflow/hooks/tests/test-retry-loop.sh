#!/bin/bash
# test-retry-loop.sh — Unit tests for retry_loop detection in observe.sh post
# Usage: bash templates/devflow/hooks/tests/test-retry-loop.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/observe.sh"
PASS=0
FAIL=0
ERRORS=()

# ── helpers ──────────────────────────────────────────────────────────────────

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
}

# Run observe.sh post in a temp workdir with a pre-populated observe log.
# Args:
#   $1 workdir
#   $2 tool name for the current event
#   $3 is_error (true/false/null)
#   $4 session id
run_post() {
  local workdir="$1" tool="$2" is_error="$3" session="$4"
  local payload
  payload=$(jq -cn \
    --arg tool "$tool" \
    --arg session "$session" \
    --argjson is_error "$is_error" \
    '{tool_use:{name:$tool}, session_id:$session, tool_result:{is_error:$is_error}}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" post >/dev/null 2>&1) || true
}

assert_retry_loop_count() {
  local workdir="$1" expected="$2" label="$3"
  local actual=0
  if [ -f "$workdir/.devflow-learnings.jsonl" ]; then
    actual=$(grep -c '"type":"retry_loop"' "$workdir/.devflow-learnings.jsonl" 2>/dev/null || echo 0)
  fi
  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $label (expected $expected retry_loop entries, got $actual)")
    echo "  FAIL: $label (expected $expected retry_loop entries, got $actual)"
  fi
}

assert_no_retry_loop() {
  assert_retry_loop_count "$1" 0 "$2"
}

assert_one_retry_loop() {
  assert_retry_loop_count "$1" 1 "$2"
}

assert_retry_loop_tool() {
  local workdir="$1" expected_tool="$2" label="$3"
  local actual_tool=""
  if [ -f "$workdir/.devflow-learnings.jsonl" ]; then
    actual_tool=$(grep '"type":"retry_loop"' "$workdir/.devflow-learnings.jsonl" 2>/dev/null \
      | tail -1 | jq -r '.tool // empty' 2>/dev/null) || true
  fi
  if [ "$actual_tool" = "$expected_tool" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $label (expected tool='$expected_tool', got '$actual_tool')")
    echo "  FAIL: $label (expected tool='$expected_tool', got '$actual_tool')"
  fi
}

# Populate .devflow-observe.jsonl with synthetic post events
seed_post_events() {
  local workdir="$1"
  shift
  # remaining args: "tool:is_error" pairs
  local log="$workdir/.devflow-observe.jsonl"
  local i=0
  for pair in "$@"; do
    local t="${pair%%:*}"
    local err="${pair##*:}"
    jq -cn \
      --arg ts "2026-05-26T00:00:0${i}Z" \
      --arg tool "$t" \
      --argjson is_error "$err" \
      '{ts:$ts, event:"post", tool:$tool, is_error:$is_error}' \
      >> "$log"
    i=$((i + 1))
  done
}

# ── Test 1: 3 consecutive identical tool calls → retry_loop written ───────────
echo "Test 1: 3 consecutive identical post events → writes retry_loop"
W=$(tmpdir)
seed_post_events "$W" "Bash:false" "Bash:true" "Bash:true"
run_post "$W" "Bash" "true" "sess-001"
assert_one_retry_loop "$W" "3 identical tool calls trigger retry_loop"
rm -rf "$W"

# ── Test 2: 4 consecutive identical tool calls → still exactly 1 entry ────────
echo "Test 2: 4 consecutive identical post events → exactly 1 retry_loop entry"
W=$(tmpdir)
seed_post_events "$W" "Bash:false" "Bash:true" "Bash:true" "Bash:true"
run_post "$W" "Bash" "true" "sess-002"
assert_retry_loop_count "$W" 1 "4 identical calls = 1 entry (dedup)"
rm -rf "$W"

# ── Test 3: 2 calls only → no retry_loop ──────────────────────────────────────
echo "Test 3: only 2 consecutive post events for same tool → no retry_loop"
W=$(tmpdir)
seed_post_events "$W" "Bash:false" "Bash:true"
run_post "$W" "Bash" "true" "sess-003"
assert_no_retry_loop "$W" "2 calls does not trigger retry_loop"
rm -rf "$W"

# ── Test 4: tool changes between calls → no retry_loop ────────────────────────
echo "Test 4: tool changes mid-sequence → no retry_loop"
W=$(tmpdir)
seed_post_events "$W" "Bash:true" "Read:false" "Bash:true"
run_post "$W" "Bash" "true" "sess-004"
assert_no_retry_loop "$W" "non-consecutive calls do not trigger retry_loop"
rm -rf "$W"

# ── Test 5: entry contains correct tool name ───────────────────────────────────
echo "Test 5: retry_loop entry records the correct tool name"
W=$(tmpdir)
seed_post_events "$W" "Edit:true" "Edit:true"
run_post "$W" "Edit" "true" "sess-005"
assert_retry_loop_tool "$W" "Edit" "retry_loop entry has correct tool field"
rm -rf "$W"

# ── Test 6: dedup — second identical session+tool does not add another entry ──
echo "Test 6: dedup — same tool+session in learnings → no duplicate entry"
W=$(tmpdir)
seed_post_events "$W" "Bash:true" "Bash:true"
# Pre-populate learnings with an existing entry for same tool+session
jq -cn \
  --arg ts "2026-05-26T00:00:00Z" \
  --arg tool "Bash" \
  --arg session "sess-006" \
  '{ts:$ts, type:"retry_loop", source:"auto", tool:$tool, session:$session}' \
  > "$W/.devflow-learnings.jsonl"
run_post "$W" "Bash" "true" "sess-006"
assert_retry_loop_count "$W" 1 "dedup: no duplicate retry_loop for same tool+session"
rm -rf "$W"

# ── Test 7: different tools each trigger their own entry ──────────────────────
echo "Test 7: different tools can each trigger a separate retry_loop entry"
W=$(tmpdir)
# First trigger for Bash
seed_post_events "$W" "Bash:true" "Bash:true"
run_post "$W" "Bash" "true" "sess-007"
# Then trigger for Edit (reset log)
rm -f "$W/.devflow-observe.jsonl"
seed_post_events "$W" "Edit:true" "Edit:true"
run_post "$W" "Edit" "true" "sess-007"
assert_retry_loop_count "$W" 2 "two different tools each get a retry_loop entry"
rm -rf "$W"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo ""
  for e in "${ERRORS[@]}"; do
    echo "  $e"
  done
  exit 1
fi
exit 0
