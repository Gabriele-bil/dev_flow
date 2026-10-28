#!/bin/bash
# test-post-model-switch.sh — Unit tests for post-model-switch.sh audit logging
# Usage: bash templates/devflow/hooks/tests/test-post-model-switch.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/post-model-switch.sh"
PASS=0
FAIL=0
ERRORS=()

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

run_hook() {
  local workdir="$1" event_json="$2"
  (cd "$workdir" && printf '%s' "$event_json" | bash "$HOOK" >/tmp/devflow-test-postmodelswitch-out 2>&1) || true
}

# ── T1: appends one JSONL line with from/to on a real switch ───────────────
d=$(tmpdir)
run_hook "$d" '{"to_model":"claude-opus-5","from_model":"claude-sonnet-5","session_id":"abc123"}'
LOG="$d/.devflow-model-switch.jsonl"
[ -f "$LOG" ] && [ "$(wc -l < "$LOG" | tr -d '[:space:]')" = "1" ] \
  && assert "T1: appends one JSONL line" pass \
  || assert "T1: appends one JSONL line" fail

TO=$(jq -r '.to' "$LOG" 2>/dev/null || true)
[ "$TO" = "claude-opus-5" ] \
  && assert "T1b: to_model recorded correctly" pass \
  || assert "T1b: to_model recorded correctly" fail
rm -rf "$d"

# ── T2: no model fields → no file written ───────────────────────────────────
d=$(tmpdir)
run_hook "$d" '{}'
[ ! -f "$d/.devflow-model-switch.jsonl" ] \
  && assert "T2: no file written when both model fields absent" pass \
  || assert "T2: no file written when both model fields absent" fail
rm -rf "$d"

# ── T3: gitignore entry added when .gitignore exists ────────────────────────
d=$(tmpdir)
: > "$d/.gitignore"
run_hook "$d" '{"to_model":"claude-sonnet-5","from_model":"claude-opus-5"}'
grep -qF ".devflow-model-switch.jsonl" "$d/.gitignore" \
  && assert "T3: gitignore entry added" pass \
  || assert "T3: gitignore entry added" fail
rm -rf "$d"

# ── T4: DEVFLOW_MODEL_SWITCH_LOG=off disables logging ───────────────────────
d=$(tmpdir)
(cd "$d" && DEVFLOW_MODEL_SWITCH_LOG=off bash "$HOOK" <<<'{"to_model":"claude-sonnet-5","from_model":"claude-opus-5"}' >/dev/null 2>&1) || true
[ ! -f "$d/.devflow-model-switch.jsonl" ] \
  && assert "T4: DEVFLOW_MODEL_SWITCH_LOG=off disables logging" pass \
  || assert "T4: DEVFLOW_MODEL_SWITCH_LOG=off disables logging" fail
rm -rf "$d"

echo ""
echo "── test-post-model-switch.sh: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
