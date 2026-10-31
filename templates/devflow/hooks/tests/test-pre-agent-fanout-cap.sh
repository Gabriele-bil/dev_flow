#!/bin/bash
# test-pre-agent-fanout-cap.sh — Unit tests for pre-agent-fanout-cap.sh
# Usage: bash templates/devflow/hooks/tests/test-pre-agent-fanout-cap.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-agent-fanout-cap.sh"
PASS=0
FAIL=0
ERRORS=()

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export DEVFLOW_FANOUT_STATE_FILE="$TMPDIR/.devflow-fanout-state.json"
export DEVFLOW_MAX_FANOUT=5
export DEVFLOW_FANOUT_WINDOW_MS=10000

run_hook() {
  (cd "$TMPDIR" && printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{}}' | bash "$HOOK" 2>/dev/null) || true
}

echo "=== test-pre-agent-fanout-cap.sh ==="
echo ""

echo "--- T1: calls 1-5 within window allowed ---"
rm -f "$TMPDIR/.devflow-fanout-state.json"
ALL_ALLOWED=true
for _ in 1 2 3 4 5; do
  out=$(run_hook)
  [ -z "$out" ] || ALL_ALLOWED=false
done
[ "$ALL_ALLOWED" = true ] && assert "calls 1-5 allowed" pass || assert "calls 1-5 allowed" fail

echo "--- T2: 6th call within window blocked ---"
out=$(run_hook)
echo "$out" | grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' \
  && assert "6th call blocked" pass \
  || assert "6th call blocked (output: '$out')" fail

echo "--- T3: gap beyond window resets counter ---"
rm -f "$TMPDIR/.devflow-fanout-state.json"
out=$(run_hook)
[ -z "$out" ] && assert "first call after reset allowed" pass || assert "first call after reset allowed" fail

echo "--- T4: degenerate input allowed silently ---"
rm -f "$TMPDIR/.devflow-fanout-state.json"
out=$(cd "$TMPDIR" && printf '' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "empty stdin allowed" pass || assert "empty stdin allowed" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
