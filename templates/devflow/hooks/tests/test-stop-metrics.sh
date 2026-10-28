#!/bin/bash
# test-stop-metrics.sh — Unit tests for stop-metrics.sh token/cost aggregation
# Usage: bash templates/devflow/hooks/tests/test-stop-metrics.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/stop-metrics.sh"
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

write_transcript() {
  local path="$1"
  cat > "$path" <<'EOF'
{"type":"assistant","message":{"id":"msg_1","model":"claude-sonnet-5","usage":{"input_tokens":1000,"output_tokens":200,"cache_creation_input_tokens":50,"cache_read_input_tokens":10}}}
{"type":"user","message":{"content":"hi"}}
{"type":"assistant","message":{"id":"msg_1","model":"claude-sonnet-5","usage":{"input_tokens":1000,"output_tokens":200,"cache_creation_input_tokens":50,"cache_read_input_tokens":10}}}
{"type":"assistant","message":{"id":"msg_2","model":"claude-sonnet-5","usage":{"input_tokens":500,"output_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
EOF
}

run_hook() {
  local workdir="$1" event_json="$2"
  (cd "$workdir" && printf '%s' "$event_json" | bash "$HOOK" >/tmp/devflow-test-stopmetrics-out 2>&1) || true
}

# ── T1: sums usage, dedups repeated message id, computes sonnet cost ───────
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s1\"}"
LOG="$d/.devflow-metrics.jsonl"
[ -f "$LOG" ] \
  && assert "T1: metrics file written" pass \
  || assert "T1: metrics file written" fail

INPUT=$(jq -r '.input_tokens' "$LOG" 2>/dev/null || echo "")
[ "$INPUT" = "1500" ] \
  && assert "T1b: input tokens deduped by message id (1000+500)" pass \
  || assert "T1b: input tokens deduped by message id (1000+500, got $INPUT)" fail

COST=$(jq -r '.estimated_cost_usd' "$LOG" 2>/dev/null || echo "")
[ "$COST" != "null" ] && [ -n "$COST" ] \
  && assert "T1c: cost estimated for known model" pass \
  || assert "T1c: cost estimated for known model" fail
rm -rf "$d"

# ── T2: missing transcript file → no log written ────────────────────────────
d=$(tmpdir)
run_hook "$d" "{\"transcript_path\":\"$d/does-not-exist.jsonl\"}"
[ ! -f "$d/.devflow-metrics.jsonl" ] \
  && assert "T2: no log when transcript missing" pass \
  || assert "T2: no log when transcript missing" fail
rm -rf "$d"

# ── T3: DEVFLOW_METRICS_LOG=off disables logging ────────────────────────────
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
(cd "$d" && DEVFLOW_METRICS_LOG=off bash "$HOOK" <<<"{\"transcript_path\":\"$d/transcript.jsonl\"}" >/dev/null 2>&1) || true
[ ! -f "$d/.devflow-metrics.jsonl" ] \
  && assert "T3: DEVFLOW_METRICS_LOG=off disables logging" pass \
  || assert "T3: DEVFLOW_METRICS_LOG=off disables logging" fail
rm -rf "$d"

# ── T4: unknown model → tokens recorded, cost null ──────────────────────────
d=$(tmpdir)
cat > "$d/transcript.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"msg_1","model":"some-future-model","usage":{"input_tokens":100,"output_tokens":50}}}
EOF
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\"}"
COST=$(jq -r '.estimated_cost_usd // "absent"' "$d/.devflow-metrics.jsonl" 2>/dev/null || echo "")
[ "$COST" = "absent" ] \
  && assert "T4: unknown model omits cost field" pass \
  || assert "T4: unknown model omits cost field (got $COST)" fail
rm -rf "$d"

# ── T5: command timing telemetry (.devflow-timings.jsonl) + active_feature ──
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
cat > "$d/.devflow-state.json" <<'EOF'
{
  "active_feature": "003_devflow-board",
  "next_step": "devflow.implement"
}
EOF
cat > "$d/.devflow-observe-state.json" <<'EOF'
{
  "active_command": "implement",
  "turn_started_at": "2026-10-26T08:00:00Z",
  "turn_started_epoch": 1000
}
EOF
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-timing\"}"
TLOG="$d/.devflow-timings.jsonl"
[ -f "$TLOG" ] \
  && assert "T5a: timings file written" pass \
  || assert "T5a: timings file written" fail
T_FEAT=$(jq -r '.active_feature // empty' "$TLOG" 2>/dev/null || echo "")
[ "$T_FEAT" = "003_devflow-board" ] \
  && assert "T5b: active_feature recorded in timings" pass \
  || assert "T5b: active_feature recorded in timings (got '$T_FEAT')" fail
T_CMD=$(jq -r '.command // empty' "$TLOG" 2>/dev/null || echo "")
[ "$T_CMD" = "implement" ] \
  && assert "T5c: command recorded in timings" pass \
  || assert "T5c: command recorded in timings (got '$T_CMD')" fail
T_DUR=$(jq -r '.duration_sec // 0' "$TLOG" 2>/dev/null || echo "0")
[ "$T_DUR" -gt 0 ] \
  && assert "T5d: duration_sec computed (>0)" pass \
  || assert "T5d: duration_sec computed (>0, got '$T_DUR')" fail
rm -rf "$d"

# ── T6: per-turn usage — a second Stop with no new transcript lines adds 0 ──
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-turn\"}"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-turn\"}"
ROWS=$(wc -l < "$d/.devflow-metrics.jsonl" 2>/dev/null | tr -d ' ')
[ "$ROWS" = "1" ] \
  && assert "T6: no double-count when transcript did not grow" pass \
  || assert "T6: no double-count when transcript did not grow (rows=$ROWS)" fail
rm -rf "$d"

# ── T7: cache reads priced at the cache_read rate, not the input rate ──────
d=$(tmpdir)
printf '%s\n' '{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":1000000}}}' > "$d/transcript.jsonl"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-cache\"}"
C=$(jq -r '.estimated_cost_usd' "$d/.devflow-metrics.jsonl" 2>/dev/null)
[ "$C" = "0.2" ] \
  && assert "T7: 1M cache-read tokens on Opus 5.5 cost 0.20 USD" pass \
  || assert "T7: 1M cache-read tokens on Opus 5.5 cost 0.20 USD (got $C)" fail
rm -rf "$d"

# ── T8: Antigravity transcript (PLANNER_RESPONSE token fields) ──────────────
d=$(tmpdir)
printf '%s\n' '{"step_index":1,"type":"PLANNER_RESPONSE","input_tokens":6884,"cache_read_tokens":0,"output_tokens":582}' > "$d/transcript_full.jsonl"
run_hook "$d" "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$d\"],\"transcriptPath\":\"$d/transcript_full.jsonl\",\"modelName\":\"gemini-3.8-flash-high\"}"
IN=$(jq -r '.input_tokens' "$d/.devflow-metrics.jsonl" 2>/dev/null)
[ "$IN" = "6884" ] \
  && assert "T8: Antigravity tokens recorded" pass \
  || assert "T8: Antigravity tokens recorded (got $IN)" fail
rm -rf "$d"

echo ""
echo "── test-stop-metrics.sh: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
