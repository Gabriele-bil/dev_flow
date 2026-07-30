#!/bin/bash
# test-revert-decay.sh — Unit tests for revert-decay of churn instincts
# (observe.sh Bash-command capture + stop-learn-distill.sh contest logic).
# Usage: bash templates/devflow/hooks/tests/test-revert-decay.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OBSERVE="$HOOKS_DIR/observe.sh"
DISTILL="$HOOKS_DIR/stop-learn-distill.sh"
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

tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t devflow-test
}

# Log N pre/post Edit events for a file (simulates churn), plus optionally a
# Bash command (e.g. a revert), all inside $workdir.
churn_file() {
  local workdir="$1" file="$2" count="$3"
  local i
  for ((i = 0; i < count; i++)); do
    payload=$(jq -cn --arg fp "$file" '{tool_use:{name:"Edit",input:{file_path:$fp}}, session_id:"s1"}')
    (cd "$workdir" && printf '%s' "$payload" | bash "$OBSERVE" pre >/dev/null 2>&1) || true
  done
}

log_bash_cmd() {
  local workdir="$1" cmd="$2"
  payload=$(jq -cn --arg c "$cmd" '{tool_use:{name:"Bash",input:{command:$c}}, session_id:"s1"}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$OBSERVE" pre >/dev/null 2>&1) || true
}

run_distill() {
  local workdir="$1"
  (cd "$workdir" && printf '{}' | bash "$DISTILL" >/dev/null 2>&1) || true
}

instinct_field() {
  local workdir="$1" id="$2" field="$3"
  yq -r ".instincts[] | select(.id == \"$id\") | .$field" "$workdir/.devflow-instincts.yaml" 2>/dev/null
}

echo "=== test-revert-decay.sh ==="
echo ""

echo "--- T1: observe.sh captures Bash command on pre event ---"
W1=$(tmpdir)
log_bash_cmd "$W1" "git reset --hard HEAD~1"
LOGGED_CMD=$(jq -r 'select(.tool=="Bash") | .cmd' "$W1/.devflow-observe.jsonl" 2>/dev/null | head -1)
[ "$LOGGED_CMD" = "git reset --hard HEAD~1" ] \
  && assert "Bash cmd captured in observe log" pass \
  || assert "Bash cmd captured in observe log (got: '$LOGGED_CMD')" fail
rm -rf "$W1"

echo "--- T2: churn without revert bumps confidence (baseline, unaffected) ---"
W2=$(tmpdir)
churn_file "$W2" "src/foo.ts" 4
run_distill "$W2"
CONF1=$(instinct_field "$W2" "churn-src-foo-ts" "confidence")
[ "$CONF1" = "0.5" ] && assert "first churn creates instinct at 0.5" pass \
  || assert "first churn creates instinct at 0.5 (got: '$CONF1')" fail

churn_file "$W2" "src/foo.ts" 4
run_distill "$W2"
CONF2=$(instinct_field "$W2" "churn-src-foo-ts" "confidence")
[ "$CONF2" = "0.55" ] && assert "second churn bumps to 0.55" pass \
  || assert "second churn bumps to 0.55 (got: '$CONF2')" fail
rm -rf "$W2"

echo "--- T3: churn + revert in same session contests (decays) the instinct ---"
W3=$(tmpdir)
churn_file "$W3" "src/bar.ts" 4
run_distill "$W3"
CONF_BEFORE=$(instinct_field "$W3" "churn-src-bar-ts" "confidence")

log_bash_cmd "$W3" "git reset --hard HEAD~1"
churn_file "$W3" "src/bar.ts" 4
run_distill "$W3"
CONF_AFTER=$(instinct_field "$W3" "churn-src-bar-ts" "confidence")
CONTESTED=$(instinct_field "$W3" "churn-src-bar-ts" "contested")

[ "$CONF_BEFORE" = "0.5" ] && assert "pre-revert confidence is 0.5" pass \
  || assert "pre-revert confidence is 0.5 (got: '$CONF_BEFORE')" fail
[ "$CONF_AFTER" = "0.30" ] && assert "post-revert confidence decayed to 0.30" pass \
  || assert "post-revert confidence decayed to 0.30 (got: '$CONF_AFTER')" fail
[ "$CONTESTED" = "true" ] && assert "instinct marked contested" pass \
  || assert "instinct marked contested (got: '$CONTESTED')" fail
rm -rf "$W3"

echo "--- T4: revert with no prior instinct does not create a stub ---"
W4=$(tmpdir)
log_bash_cmd "$W4" "git checkout -- ."
churn_file "$W4" "src/baz.ts" 4
run_distill "$W4"
EXISTS=$(instinct_field "$W4" "churn-src-baz-ts" "id")
[ -z "$EXISTS" ] && assert "no stub created when revert precedes first churn" pass \
  || assert "no stub created when revert precedes first churn (got: '$EXISTS')" fail
rm -rf "$W4"

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
