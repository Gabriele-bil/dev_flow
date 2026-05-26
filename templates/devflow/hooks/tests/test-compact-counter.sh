#!/bin/bash
# test-compact-counter.sh — Unit tests for strategic-compact counter in observe.sh
# Usage: bash templates/devflow/hooks/tests/test-compact-counter.sh
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

run_post() {
  local workdir="$1" tool="${2:-Bash}" session="${3:-sess-001}" step="${4:-}"
  local payload
  payload=$(jq -cn \
    --arg tool    "$tool" \
    --arg session "$session" \
    --arg step    "$step" \
    '{
      tool_use:    {name: $tool},
      session_id:  $session,
      tool_result: {is_error: false}
    }')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" post 2>/tmp/devflow-test-stderr) || true
}

run_stop() {
  local workdir="$1" session="${2:-sess-001}"
  local payload
  payload=$(jq -cn --arg session "$session" '{session_id: $session}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" stop 2>/tmp/devflow-test-stderr) || true
}

read_counter() {
  local workdir="$1"
  jq -r '.tool_call_count // 0' "$workdir/.devflow-state.json" 2>/dev/null || echo 0
}

read_last_session() {
  local workdir="$1"
  jq -r '.last_session_id // empty' "$workdir/.devflow-state.json" 2>/dev/null || echo ""
}

read_last_step() {
  local workdir="$1"
  jq -r '.last_observed_step // empty' "$workdir/.devflow-state.json" 2>/dev/null || echo ""
}

stderr_contains() {
  grep -qF "$1" /tmp/devflow-test-stderr 2>/dev/null
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

# ── tests ─────────────────────────────────────────────────────────────────────

echo "=== test-compact-counter.sh ==="
echo ""

# T1: counter increments on post
echo "--- T1: counter increments on post ---"
D=$(tmpdir)
run_post "$D" Bash sess-1
count=$(read_counter "$D")
[ "$count" -eq 1 ] && assert "counter is 1 after first post" pass \
                    || assert "counter is 1 after first post (got $count)" fail
run_post "$D" Bash sess-1
count=$(read_counter "$D")
[ "$count" -eq 2 ] && assert "counter is 2 after second post" pass \
                    || assert "counter is 2 after second post (got $count)" fail
rm -rf "$D"

# T2: last_session_id written correctly
echo "--- T2: last_session_id stored ---"
D=$(tmpdir)
run_post "$D" Bash sess-abc
sess=$(read_last_session "$D")
[ "$sess" = "sess-abc" ] && assert "last_session_id stored" pass \
                          || assert "last_session_id stored (got '$sess')" fail
rm -rf "$D"

# T3: counter resets on new session
echo "--- T3: counter resets on new session ---"
D=$(tmpdir)
run_post "$D" Bash sess-1
run_post "$D" Bash sess-1
run_post "$D" Bash sess-2   # new session
count=$(read_counter "$D")
[ "$count" -eq 1 ] && assert "counter reset to 1 on new session" pass \
                    || assert "counter reset to 1 on new session (got $count)" fail
rm -rf "$D"

# T4: no advisory below threshold (stop event)
echo "--- T4: no advisory below threshold at stop ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=5
for i in $(seq 1 4); do run_post "$D" Bash sess-1; done
run_stop "$D" sess-1
stderr_contains "devflow" \
  && assert "no advisory below threshold at stop" fail \
  || assert "no advisory below threshold at stop" pass
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T5: advisory emitted on stop when count >= threshold
echo "--- T5: advisory emitted at stop when threshold reached ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=3
for i in $(seq 1 3); do run_post "$D" Bash sess-1; done
run_stop "$D" sess-1
stderr_contains "devflow" \
  && assert "advisory emitted at stop (threshold=3, count=3)" pass \
  || assert "advisory emitted at stop (threshold=3, count=3)" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T6: advisory on stop contains /compact
echo "--- T6: advisory message contains /compact ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=2
for i in $(seq 1 2); do run_post "$D" Bash sess-1; done
run_stop "$D" sess-1
stderr_contains "/compact" \
  && assert "advisory mentions /compact" pass \
  || assert "advisory mentions /compact" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T7: no advisory on stop after session reset
echo "--- T7: no advisory after session reset (counter back below threshold) ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=3
for i in $(seq 1 3); do run_post "$D" Bash sess-1; done
# new session — counter resets
run_post "$D" Bash sess-2
run_stop "$D" sess-2
stderr_contains "devflow" \
  && assert "no advisory after session reset" fail \
  || assert "no advisory after session reset" pass
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T8: step-change advisory when above threshold
echo "--- T8: step-change triggers advisory when above threshold ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=2
# Seed state: counter at threshold, last_observed_step=build
printf '{"tool_call_count":2,"last_session_id":"sess-1","last_observed_step":"build"}' \
  > "$D/.devflow-state.json"
# Run post with a different step value in state (simulate step change)
(cd "$D" && jq '.next_step = "review"' .devflow-state.json > .devflow-state.json.tmp \
  && mv .devflow-state.json.tmp .devflow-state.json)
payload=$(jq -cn '{tool_use:{name:"Bash"},session_id:"sess-1",tool_result:{is_error:false}}')
(cd "$D" && printf '%s' "$payload" | bash "$HOOK" post 2>/tmp/devflow-test-stderr) || true
stderr_contains "devflow" \
  && assert "step-change triggers advisory when above threshold" pass \
  || assert "step-change triggers advisory when above threshold" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T9: no step-change advisory below threshold
echo "--- T9: no step-change advisory below threshold ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=10
printf '{"tool_call_count":1,"last_session_id":"sess-1","last_observed_step":"build","next_step":"review"}' \
  > "$D/.devflow-state.json"
payload=$(jq -cn '{tool_use:{name:"Bash"},session_id:"sess-1",tool_result:{is_error:false}}')
(cd "$D" && printf '%s' "$payload" | bash "$HOOK" post 2>/tmp/devflow-test-stderr) || true
stderr_contains "devflow" \
  && assert "no step-change advisory below threshold" fail \
  || assert "no step-change advisory below threshold" pass
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

# T10: last_observed_step updated after post
echo "--- T10: last_observed_step updated after post ---"
D=$(tmpdir)
printf '{"tool_call_count":0,"last_session_id":"sess-1","last_observed_step":"build","next_step":"plan"}' \
  > "$D/.devflow-state.json"
run_post "$D" Bash sess-1 "plan"
step=$(read_last_step "$D")
[ "$step" = "plan" ] && assert "last_observed_step updated to plan" pass \
                      || assert "last_observed_step updated to plan (got '$step')" fail
rm -rf "$D"

# T11: existing state fields preserved
echo "--- T11: existing state fields preserved ---"
D=$(tmpdir)
printf '{"feature":"my-feature","next_step":"build","tool_call_count":0,"last_session_id":"sess-1","last_observed_step":"build"}' \
  > "$D/.devflow-state.json"
run_post "$D" Bash sess-1
feature=$(jq -r '.feature // empty' "$D/.devflow-state.json" 2>/dev/null)
[ "$feature" = "my-feature" ] && assert "feature field preserved after counter write" pass \
                               || assert "feature field preserved after counter write (got '$feature')" fail
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
