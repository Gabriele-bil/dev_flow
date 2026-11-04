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
LOG="$d/.devflow-metrics/turns.jsonl"
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
[ ! -f "$d/.devflow-metrics/turns.jsonl" ] \
  && assert "T2: no log when transcript missing" pass \
  || assert "T2: no log when transcript missing" fail
rm -rf "$d"

# ── T3: DEVFLOW_METRICS_LOG=off disables logging ────────────────────────────
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
(cd "$d" && DEVFLOW_METRICS_LOG=off bash "$HOOK" <<<"{\"transcript_path\":\"$d/transcript.jsonl\"}" >/dev/null 2>&1) || true
[ ! -f "$d/.devflow-metrics/turns.jsonl" ] \
  && assert "T3: DEVFLOW_METRICS_LOG=off disables logging" pass \
  || assert "T3: DEVFLOW_METRICS_LOG=off disables logging" fail
rm -rf "$d"

# ── T4: unknown model → tokens recorded, cost null ──────────────────────────
d=$(tmpdir)
cat > "$d/transcript.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"msg_1","model":"some-future-model","usage":{"input_tokens":100,"output_tokens":50}}}
EOF
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\"}"
COST=$(jq -r '.estimated_cost_usd // "absent"' "$d/.devflow-metrics/turns.jsonl" 2>/dev/null || echo "")
[ "$COST" = "absent" ] \
  && assert "T4: unknown model omits cost field" pass \
  || assert "T4: unknown model omits cost field (got $COST)" fail
rm -rf "$d"

# ── T5: command timing telemetry (.devflow-metrics/timings.jsonl) + active_feature ──
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
TLOG="$d/.devflow-metrics/timings.jsonl"
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
ROWS=$(wc -l < "$d/.devflow-metrics/turns.jsonl" 2>/dev/null | tr -d ' ')
[ "$ROWS" = "1" ] \
  && assert "T6: no double-count when transcript did not grow" pass \
  || assert "T6: no double-count when transcript did not grow (rows=$ROWS)" fail
rm -rf "$d"

# ── T7: cache reads priced at the cache_read rate, not the input rate ──────
d=$(tmpdir)
printf '%s\n' '{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":1000000}}}' > "$d/transcript.jsonl"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-cache\"}"
C=$(jq -r '.estimated_cost_usd' "$d/.devflow-metrics/turns.jsonl" 2>/dev/null)
[ "$C" = "0.2" ] \
  && assert "T7: 1M cache-read tokens on Opus 5.5 cost 0.20 USD" pass \
  || assert "T7: 1M cache-read tokens on Opus 5.5 cost 0.20 USD (got $C)" fail
rm -rf "$d"

# ── T8: Antigravity transcript (PLANNER_RESPONSE token fields) ──────────────
d=$(tmpdir)
printf '%s\n' '{"step_index":1,"type":"PLANNER_RESPONSE","input_tokens":6884,"cache_read_tokens":0,"output_tokens":582}' > "$d/transcript_full.jsonl"
run_hook "$d" "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$d\"],\"transcriptPath\":\"$d/transcript_full.jsonl\",\"modelName\":\"gemini-3.8-flash-high\"}"
IN=$(jq -r '.input_tokens' "$d/.devflow-metrics/turns.jsonl" 2>/dev/null)
[ "$IN" = "6884" ] \
  && assert "T8: Antigravity tokens recorded" pass \
  || assert "T8: Antigravity tokens recorded (got $IN)" fail
rm -rf "$d"

# ── T9: context, thinking, tool mix, skills and slash commands per turn ─────
d=$(tmpdir)
cat > "$d/transcript.jsonl" <<'EOF'
{"type":"user","message":{"content":"<command-name>/devflow:devflow-plan</command-name>"}}
{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":10,"output_tokens":100,"cache_creation_input_tokens":4000,"cache_read_input_tokens":30000,"output_tokens_details":{"thinking_tokens":40}},"content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"devflow:devflow-plan"}}]}}
{"type":"assistant","message":{"id":"m2","model":"claude-opus-5-5","usage":{"input_tokens":5,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":20000},"content":[{"type":"tool_use","id":"t2","name":"Read","input":{}},{"type":"tool_use","id":"t3","name":"Read","input":{}}]}}
EOF
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-ctx\"}"
ROW=$(cat "$d/.devflow-metrics/turns.jsonl" 2>/dev/null)
[ "$(jq -r '.context_tokens' <<<"$ROW")" = "20005" ] && [ "$(jq -r '.peak_context_tokens' <<<"$ROW")" = "34010" ] \
  && assert "T9a: context_tokens = last call prompt, peak = largest" pass \
  || assert "T9a: context_tokens/peak (got $(jq -c '[.context_tokens,.peak_context_tokens]' <<<"$ROW"))" fail
[ "$(jq -r '.thinking_tokens' <<<"$ROW")" = "40" ] && [ "$(jq -r '.api_calls' <<<"$ROW")" = "2" ] \
  && assert "T9b: thinking tokens and api calls" pass \
  || assert "T9b: thinking tokens and api calls" fail
[ "$(jq -c '.tool_calls' <<<"$ROW")" = '{"Read":2,"Skill":1}' ] \
  && assert "T9c: tool calls by name" pass \
  || assert "T9c: tool calls by name (got $(jq -c '.tool_calls' <<<"$ROW"))" fail
[ "$(jq -r '.skills[0]' <<<"$ROW")" = "devflow:devflow-plan" ] && [ "$(jq -r '.command' <<<"$ROW")" = "plan" ] \
  && assert "T9d: skill recorded, slash command attributes the turn" pass \
  || assert "T9d: skill recorded, slash command attributes the turn" fail
rm -rf "$d"

# ── T10: prompt-submit mark times the turn and is cleared afterwards ────────
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
START_MS=$(( ($(date +%s) - 7) * 1000 ))
printf '{"prompt_started_ms":%s}\n' "$START_MS" > "$d/.devflow-observe-state.json"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-prompt\"}"
DMS=$(jq -r '.duration_ms' "$d/.devflow-metrics/turns.jsonl" 2>/dev/null || echo 0)
[ "${DMS:-0}" -ge 6000 ] && [ "${DMS:-0}" -lt 60000 ] \
  && assert "T10a: duration_ms from prompt mark" pass \
  || assert "T10a: duration_ms from prompt mark (got $DMS)" fail
[ "$(jq -r '.prompt_started_ms // "gone"' "$d/.devflow-observe-state.json")" = "gone" ] \
  && assert "T10b: prompt mark cleared at Stop" pass \
  || assert "T10b: prompt mark cleared at Stop" fail
rm -rf "$d"

# ── T11: DEVFLOW_METRICS_DIR=off disables the whole folder ──────────────────
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
(cd "$d" && DEVFLOW_METRICS_DIR=off bash "$HOOK" <<<"{\"transcript_path\":\"$d/transcript.jsonl\"}" >/dev/null 2>&1) || true
[ ! -e "$d/.devflow-metrics" ] && [ ! -e "$d/off" ] \
  && assert "T11: DEVFLOW_METRICS_DIR=off writes nothing" pass \
  || assert "T11: DEVFLOW_METRICS_DIR=off writes nothing" fail
rm -rf "$d"

# ── T12: pre-2.1 root logs migrate into the folder on first use ─────────────
d=$(tmpdir)
write_transcript "$d/transcript.jsonl"
printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","input_tokens":1}' > "$d/.devflow-metrics.jsonl"
printf '%s\n' '{"ts":"2026-01-01T00:00:00Z","command":"task"}' > "$d/.devflow-timings.jsonl"
run_hook "$d" "{\"transcript_path\":\"$d/transcript.jsonl\",\"session_id\":\"s-mig\"}"
[ ! -f "$d/.devflow-metrics.jsonl" ] && [ "$(wc -l < "$d/.devflow-metrics/turns.jsonl" | tr -d ' ')" = "2" ] \
  && [ "$(head -1 "$d/.devflow-metrics/timings.jsonl" | jq -r '.command')" = "task" ] \
  && assert "T12: legacy rows moved, new row appended" pass \
  || assert "T12: legacy rows moved, new row appended" fail
rm -rf "$d"

echo ""
echo "── test-stop-metrics.sh: $PASS passed, $FAIL failed ──"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
