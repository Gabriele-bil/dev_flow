#!/bin/bash
# test-pre-scope-guard.sh — Unit tests for pre-scope-guard.sh (soft warn only)
# Usage: bash templates/devflow/hooks/tests/test-pre-scope-guard.sh
# Exit code: 0 = all pass, non-zero = failure

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-scope-guard.sh"
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

D=$(mktemp -d); D=$(cd "$D" && pwd -P)
trap 'rm -rf "$D"' EXIT
(cd "$D" && git init -q 2>/dev/null) || true
mkdir -p "$D/devflow/features/001_login"
cat > "$D/devflow/features/001_login/plan.md" <<'EOF'
# Plan
**Status:** implementing

## File List
### `src/auth/login.ts` [pending]
EOF
printf '{"feature":"001_login","feature_path":"devflow/features/001_login"}' > "$D/.devflow-state.json"

run_hook() {
  jq -cn --arg f "$1" --arg cwd "$D" \
    '{hook_event_name: "PreToolUse", cwd: $cwd, tool_name: "Edit", tool_input: {file_path: $f}}' \
    | bash "$HOOK" 2>/dev/null
}

echo "=== test-pre-scope-guard.sh ==="
echo ""

echo "--- T1: file listed in plan → silent ---"
out=$(run_hook "$D/src/auth/login.ts")
[ -z "$out" ] && assert "listed file allowed silently" pass || assert "listed file allowed silently (got '$out')" fail

echo "--- T2: unlisted file during implementing → additionalContext warning, never a deny ---"
out=$(run_hook "$D/src/billing/pay.ts")
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput.additionalContext | test("Scope Guard"))' >/dev/null 2>&1 \
  && assert "soft warning as additionalContext" pass || assert "soft warning as additionalContext (got '$out')" fail
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1 \
  && assert "never blocks" fail || assert "never blocks" pass
printf '%s' "$out" | grep -q "## Deviations" \
  && assert "points to the ## Deviations section" pass || assert "points to the ## Deviations section" fail

echo "--- T3: tests and devflow artefacts are exempt ---"
out=$(run_hook "$D/src/billing/pay.spec.ts")
[ -z "$out" ] && assert "spec file exempt" pass || assert "spec file exempt (got '$out')" fail
out=$(run_hook "$D/devflow/features/001_login/plan.md")
[ -z "$out" ] && assert "plan.md exempt" pass || assert "plan.md exempt (got '$out')" fail

echo "--- T4: plan not in implementing → silent ---"
sed -i.bak 's/implementing/implemented/' "$D/devflow/features/001_login/plan.md"
out=$(run_hook "$D/src/billing/pay.ts")
[ -z "$out" ] && assert "inactive outside implementing" pass || assert "inactive outside implementing (got '$out')" fail

echo "--- T5: degenerate input → silent ---"
out=$(printf '' | bash "$HOOK" 2>/dev/null)
[ -z "$out" ] && assert "empty stdin silent" pass || assert "empty stdin silent" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
