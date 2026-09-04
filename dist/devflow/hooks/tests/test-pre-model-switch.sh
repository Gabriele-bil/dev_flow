#!/bin/bash
# test-pre-model-switch.sh — Unit tests for pre-model-switch.sh block/allow logic
# Usage: bash templates/devflow/hooks/tests/test-pre-model-switch.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-model-switch.sh"
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

write_state() {
  local dir="$1" step="$2"
  printf '{"next_step":"%s"}\n' "$step" > "$dir/.devflow-state.json"
}

run_hook() {
  local workdir="$1" event_json="$2"
  (cd "$workdir" && printf '%s' "$event_json" | bash "$HOOK" 2>/tmp/devflow-test-premodelswitch-err) || true
}

# ── T1: blocks Haiku switch during devflow.ship ─────────────────────────────
d=$(tmpdir)
write_state "$d" "devflow.ship"
out=$(run_hook "$d" '{"to_model":"claude-haiku-4-5","from_model":"claude-sonnet-5"}')
[ "$(printf '%s' "$out" | jq -r '.decision // empty' 2>/dev/null)" = "block" ] \
  && assert "T1: blocks Haiku switch during devflow.ship" pass \
  || assert "T1: blocks Haiku switch during devflow.ship" fail
rm -rf "$d"

# ── T2: allows Haiku switch outside ship/test steps ─────────────────────────
d=$(tmpdir)
write_state "$d" "devflow.task"
out=$(run_hook "$d" '{"to_model":"claude-haiku-4-5","from_model":"claude-sonnet-5"}')
[ -z "$out" ] \
  && assert "T2: allows Haiku switch during devflow.task" pass \
  || assert "T2: allows Haiku switch during devflow.task" fail
rm -rf "$d"

# ── T3: allows Sonnet/Opus switch during devflow.ship ───────────────────────
d=$(tmpdir)
write_state "$d" "devflow.ship"
out=$(run_hook "$d" '{"to_model":"claude-opus-5","from_model":"claude-sonnet-5"}')
[ -z "$out" ] \
  && assert "T3: allows Opus switch during devflow.ship" pass \
  || assert "T3: allows Opus switch during devflow.ship" fail
rm -rf "$d"

# ── T4: no state file → allow (fail-open) ───────────────────────────────────
d=$(tmpdir)
out=$(run_hook "$d" '{"to_model":"claude-haiku-4-5"}')
[ -z "$out" ] \
  && assert "T4: fail-open with no state file" pass \
  || assert "T4: fail-open with no state file" fail
rm -rf "$d"

# ── T5: no to_model field → allow (fail-open) ───────────────────────────────
d=$(tmpdir)
write_state "$d" "devflow.ship"
out=$(run_hook "$d" '{}')
[ -z "$out" ] \
  && assert "T5: fail-open with no to_model field" pass \
  || assert "T5: fail-open with no to_model field" fail
rm -rf "$d"

echo ""
echo "── test-pre-model-switch.sh: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
