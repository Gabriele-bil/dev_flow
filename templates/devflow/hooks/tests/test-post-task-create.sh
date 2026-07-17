#!/bin/bash
# test-post-task-create.sh — Unit tests for post-task-create.sh feature numbering
# Usage: bash templates/devflow/hooks/tests/test-post-task-create.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/post-task-create.sh"
PASS=0
FAIL=0
ERRORS=()

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
}

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

run_hook() {
  local workdir="$1" file_path="$2"
  local payload
  payload=$(jq -cn --arg fp "$file_path" '{tool_use: {input: {file_path: $fp}}}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK") || true
}

echo "=== test-post-task-create.sh ==="
echo ""

# T1: task.md write updates next_feature_number
echo "--- T1: counter from task.md path ---"
D=$(tmpdir)
run_hook "$D" "devflow/features/007_user-profile/task.md"
got=$(jq -r '.next_feature_number // empty' "$D/.devflow-state.json" 2>/dev/null)
[ "$got" = "008" ] \
  && assert "next_feature_number is 008" pass \
  || assert "next_feature_number is 008 (got '$got')" fail
rm -rf "$D"

# T2: non-matching path → no state file
echo "--- T2: non-task writes ignored ---"
D=$(tmpdir)
run_hook "$D" "lib/main.dart"
[ ! -f "$D/.devflow-state.json" ] \
  && assert "no state file for source write" pass \
  || assert "no state file for source write" fail
run_hook "$D" "devflow/features/007_user-profile/plan.md"
[ ! -f "$D/.devflow-state.json" ] \
  && assert "no state file for plan.md write" pass \
  || assert "no state file for plan.md write" fail
rm -rf "$D"

# T3: existing state fields preserved on merge
echo "--- T3: merge preserves existing fields ---"
D=$(tmpdir)
printf '{"feature":"003_older","plan_status":"tested"}' > "$D/.devflow-state.json"
run_hook "$D" "devflow/features/004_newer/task.md"
feature=$(jq -r '.feature // empty' "$D/.devflow-state.json" 2>/dev/null)
next=$(jq -r '.next_feature_number // empty' "$D/.devflow-state.json" 2>/dev/null)
[ "$feature" = "003_older" ] \
  && assert "existing feature field preserved" pass \
  || assert "existing feature field preserved (got '$feature')" fail
[ "$next" = "005" ] \
  && assert "next_feature_number merged as 005" pass \
  || assert "next_feature_number merged as 005 (got '$next')" fail
rm -rf "$D"

# T4: absolute-style path with prefix still matches
echo "--- T4: nested path prefix ---"
D=$(tmpdir)
run_hook "$D" "/repo/devflow/features/099_last/task.md"
got=$(jq -r '.next_feature_number // empty' "$D/.devflow-state.json" 2>/dev/null)
[ "$got" = "100" ] \
  && assert "099 rolls to 100" pass \
  || assert "099 rolls to 100 (got '$got')" fail
rm -rf "$D"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
