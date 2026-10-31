#!/bin/bash
# test-pre-compact.sh — Unit tests for pre-compact.sh state snapshot generation
# Usage: bash templates/devflow/hooks/tests/test-pre-compact.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-compact.sh"
PASS=0
FAIL=0
ERRORS=()

# ── helpers ──────────────────────────────────────────────────────────────────

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
}

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    ERRORS+=("FAIL: $label")
    echo "  FAIL: $label"
  fi
}

# Fixture: plan.md with status + done/pending File List entries
write_plan() {
  local dir="$1" status="$2"
  mkdir -p "$dir/devflow/features/001_test-feature"
  cat > "$dir/devflow/features/001_test-feature/plan.md" <<EOF
# Plan - Test Feature

**ID:** PLAN-001
**Status:** $status

## File List

### 001. \`lib/a.dart\` - create [done]
First file.

### 002. \`lib/b.dart\` - create [done]
Second file.

### 003. \`lib/c.dart\` - create [pending]
Third file.
EOF
}

run_hook() {
  local workdir="$1"
  (cd "$workdir" && echo '{}' | bash "$HOOK" >/tmp/devflow-test-precompact-out 2>&1) || true
}

state_field() {
  local workdir="$1" field="$2"
  jq -r "$field" "$workdir/.devflow-state.json" 2>/dev/null || echo ""
}

# ── tests ─────────────────────────────────────────────────────────────────────

echo "=== test-pre-compact.sh ==="
echo ""

# T1: state file created with correct feature + status
echo "--- T1: snapshot fields from plan.md ---"
D=$(tmpdir)
write_plan "$D" "implementing"
run_hook "$D"
[ "$(state_field "$D" '.feature')" = "001_test-feature" ] \
  && assert "feature extracted from path" pass \
  || assert "feature extracted from path (got '$(state_field "$D" '.feature')')" fail
[ "$(state_field "$D" '.plan_status')" = "implementing" ] \
  && assert "plan_status parsed" pass \
  || assert "plan_status parsed (got '$(state_field "$D" '.plan_status')')" fail
rm -rf "$D"

# T2: done/pending counts + file lists
echo "--- T2: progress counts and file lists ---"
D=$(tmpdir)
write_plan "$D" "implementing"
run_hook "$D"
[ "$(state_field "$D" '.progress.done')" = "2" ] \
  && assert "done count is 2" pass \
  || assert "done count is 2 (got '$(state_field "$D" '.progress.done')')" fail
[ "$(state_field "$D" '.progress.pending')" = "1" ] \
  && assert "pending count is 1" pass \
  || assert "pending count is 1 (got '$(state_field "$D" '.progress.pending')')" fail
[ "$(state_field "$D" '.progress.total')" = "3" ] \
  && assert "total is 3" pass \
  || assert "total is 3 (got '$(state_field "$D" '.progress.total')')" fail
[ "$(state_field "$D" '.pending_files[0]')" = "lib/c.dart" ] \
  && assert "pending_files lists lib/c.dart" pass \
  || assert "pending_files lists lib/c.dart (got '$(state_field "$D" '.pending_files[0]')')" fail
[ "$(state_field "$D" '.done_files | length')" = "2" ] \
  && assert "done_files has 2 entries" pass \
  || assert "done_files has 2 entries (got '$(state_field "$D" '.done_files | length')')" fail
rm -rf "$D"

# T3: status → next_step mapping (per state-machine.md)
echo "--- T3: status to next_step mapping ---"
for pair in "ready:devflow.implement" "implemented:devflow.beautify" "beautified:devflow.test" \
            "tested:devflow.ship" "shipped:devflow.pr" "blocked:devflow.recovery"; do
  status="${pair%%:*}"; expected="${pair##*:}"
  D=$(tmpdir)
  write_plan "$D" "$status"
  run_hook "$D"
  got=$(state_field "$D" '.next_step')
  [ "$got" = "$expected" ] \
    && assert "$status → $expected" pass \
    || assert "$status → $expected (got '$got')" fail
  rm -rf "$D"
done

# T4: no plan.md → no state file, INFO message
echo "--- T4: no active plan ---"
D=$(tmpdir)
run_hook "$D"
[ ! -f "$D/.devflow-state.json" ] \
  && assert "no state file written without plan" pass \
  || assert "no state file written without plan" fail
[ ! -s /tmp/devflow-test-precompact-out ] \
  && assert "silent without an active plan" pass \
  || assert "silent without an active plan" fail
rm -rf "$D"

# T5: next_feature_number computed from highest prefix
echo "--- T5: next_feature_number ---"
D=$(tmpdir)
write_plan "$D" "ready"
mkdir -p "$D/devflow/features/007_other"
run_hook "$D"
[ "$(state_field "$D" '.next_feature_number')" = "8" ] \
  && assert "next_feature_number is 008" pass \
  || assert "next_feature_number is 008 (got '$(state_field "$D" '.next_feature_number')')" fail
rm -rf "$D"

# T6: .gitignore gains state entry when present
echo "--- T6: gitignore append ---"
D=$(tmpdir)
write_plan "$D" "ready"
touch "$D/.gitignore"
run_hook "$D"
grep -qF ".devflow-state.json" "$D/.gitignore" \
  && assert "gitignore contains .devflow-state.json" pass \
  || assert "gitignore contains .devflow-state.json" fail
rm -rf "$D"

# T7: user notice is a systemMessage naming the next step
echo "--- T7: compaction notice is a systemMessage ---"
D=$(tmpdir)
write_plan "$D" "implementing"
run_hook "$D"
jq -e '.systemMessage | test("next: devflow.implement")' /tmp/devflow-test-precompact-out >/dev/null 2>&1 \
  && assert "systemMessage names next step" pass \
  || assert "systemMessage names next step (got '$(cat /tmp/devflow-test-precompact-out)')" fail
rm -rf "$D"

# T8: snapshot merges into existing state instead of replacing it
echo "--- T8: merge preserves skill-written fields ---"
D=$(tmpdir)
write_plan "$D" "implementing"
printf '{"branch":"feat/x","task_status":"done","app":"web","active_feature":"legacy"}' > "$D/.devflow-state.json"
run_hook "$D"
[ "$(state_field "$D" '.branch')" = "feat/x" ] && [ "$(state_field "$D" '.task_status')" = "done" ] && [ "$(state_field "$D" '.app')" = "web" ] \
  && assert "branch/task_status/app preserved" pass \
  || assert "branch/task_status/app preserved (got $(cat "$D/.devflow-state.json"))" fail
[ "$(state_field "$D" '.active_feature // "gone"')" = "gone" ] \
  && assert "legacy active_feature dropped in favour of feature" pass \
  || assert "legacy active_feature dropped in favour of feature" fail

# T9: unknown plan status keeps the skills' next_step
printf '{"next_step":"devflow.analyze"}' > "$D/.devflow-state.json"
sed -i.bak 's/^\*\*Status:\*\*.*/**Status:** weird/' "$D/devflow/features/"*/plan.md
run_hook "$D"
[ "$(state_field "$D" '.next_step')" = "devflow.analyze" ] \
  && assert "unknown status keeps next_step" pass \
  || assert "unknown status keeps next_step (got '$(state_field "$D" '.next_step')')" fail
rm -rf "$D"

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "Failures:"
  for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
