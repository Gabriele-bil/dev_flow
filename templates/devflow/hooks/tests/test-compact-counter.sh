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

# Real Claude Code PostToolUse payload
run_post() {
  local workdir="$1" tool="${2:-Bash}" session="${3:-sess-001}"
  local payload
  payload=$(jq -cn --arg tool "$tool" --arg session "$session" --arg cwd "$workdir" \
    '{hook_event_name: "PostToolUse", session_id: $session, cwd: $cwd,
      tool_name: $tool, tool_input: {command: "ls"}, tool_response: {stdout: "", stderr: ""}}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" post >/dev/null 2>&1) || true
}

# Stop: stdout is the hook output (systemMessage JSON)
run_stop() {
  local workdir="$1" session="${2:-sess-001}"
  local payload
  payload=$(jq -cn --arg session "$session" --arg cwd "$workdir" \
    '{hook_event_name: "Stop", session_id: $session, cwd: $cwd}')
  (cd "$workdir" && printf '%s' "$payload" | bash "$HOOK" stop 2>/dev/null) || true
}

obs() {
  jq -r "$2" "$1/.devflow-observe-state.json" 2>/dev/null || echo ""
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

echo "--- T1: counter increments on post ---"
D=$(tmpdir)
run_post "$D" Bash sess-1
count=$(obs "$D" '.tool_call_count // 0')
[ "$count" = "1" ] && assert "counter is 1 after first post" pass \
                   || assert "counter is 1 after first post (got $count)" fail
run_post "$D" Bash sess-1
count=$(obs "$D" '.tool_call_count // 0')
[ "$count" = "2" ] && assert "counter is 2 after second post" pass \
                   || assert "counter is 2 after second post (got $count)" fail
rm -rf "$D"

echo "--- T2: last_session_id stored ---"
D=$(tmpdir)
run_post "$D" Bash sess-abc
sess=$(obs "$D" '.last_session_id // empty')
[ "$sess" = "sess-abc" ] && assert "last_session_id stored" pass \
                          || assert "last_session_id stored (got '$sess')" fail
rm -rf "$D"

echo "--- T3: counter resets on new session ---"
D=$(tmpdir)
run_post "$D" Bash sess-1
run_post "$D" Bash sess-1
run_post "$D" Bash sess-2
count=$(obs "$D" '.tool_call_count // 0')
[ "$count" = "1" ] && assert "counter reset to 1 on new session" pass \
                   || assert "counter reset to 1 on new session (got $count)" fail
rm -rf "$D"

echo "--- T4: no advisory below threshold at stop ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=5
for _ in $(seq 1 4); do run_post "$D" Bash sess-1; done
out=$(run_stop "$D" sess-1)
[ -z "$out" ] && assert "no advisory below threshold at stop" pass \
              || assert "no advisory below threshold at stop (got '$out')" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

echo "--- T5: advisory is a systemMessage mentioning /compact ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=3
for _ in $(seq 1 3); do run_post "$D" Bash sess-1; done
out=$(run_stop "$D" sess-1)
printf '%s' "$out" | jq -e '.systemMessage | test("/compact")' >/dev/null 2>&1 \
  && assert "systemMessage advisory at threshold" pass \
  || assert "systemMessage advisory at threshold (got '$out')" fail
echo "--- T6: advisory only once per session ---"
out=$(run_stop "$D" sess-1)
[ -z "$out" ] && assert "second stop stays silent" pass \
              || assert "second stop stays silent (got '$out')" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

echo "--- T7: no advisory after session reset ---"
D=$(tmpdir)
export DEVFLOW_COMPACT_THRESHOLD=3
for _ in $(seq 1 3); do run_post "$D" Bash sess-1; done
run_post "$D" Bash sess-2
out=$(run_stop "$D" sess-2)
[ -z "$out" ] && assert "no advisory after session reset" pass \
              || assert "no advisory after session reset (got '$out')" fail
unset DEVFLOW_COMPACT_THRESHOLD
rm -rf "$D"

echo "--- T8: last_observed_step tracks next_step ---"
D=$(tmpdir)
printf '{"next_step":"devflow.plan"}' > "$D/.devflow-state.json"
run_post "$D" Bash sess-1
step=$(obs "$D" '.last_observed_step // empty')
[ "$step" = "devflow.plan" ] && assert "last_observed_step = devflow.plan" pass \
                              || assert "last_observed_step = devflow.plan (got '$step')" fail
rm -rf "$D"

echo "--- T9: pipeline state file is never rewritten by observe ---"
D=$(tmpdir)
printf '{"feature":"001_x","next_step":"devflow.plan"}' > "$D/.devflow-state.json"
before=$(cat "$D/.devflow-state.json")
run_post "$D" Bash sess-1
after=$(cat "$D/.devflow-state.json")
[ "$before" = "$after" ] && assert ".devflow-state.json untouched" pass \
                         || assert ".devflow-state.json untouched (got '$after')" fail
rm -rf "$D"

echo "--- T10: concurrent posts lose no updates and never empty the file ---"
D=$(tmpdir)
for _ in $(seq 1 12); do run_post "$D" Bash sess-1 & done
wait
count=$(obs "$D" '.tool_call_count // 0')
[ "$count" = "12" ] && assert "12 concurrent posts counted as 12" pass \
                    || assert "12 concurrent posts counted as 12 (got '$count')" fail
jq -e 'type == "object"' "$D/.devflow-observe-state.json" >/dev/null 2>&1 \
  && assert "observe state is valid JSON after the race" pass \
  || assert "observe state is valid JSON after the race" fail
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
