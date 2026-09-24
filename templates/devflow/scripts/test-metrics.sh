#!/bin/bash
# test-metrics.sh — Unit tests for metrics.sh
# Usage: bash templates/devflow/scripts/test-metrics.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
METRICS_SH="$SCRIPT_DIR/metrics.sh"
PASS=0
FAIL=0
T=""
ORIG_DIR="$PWD"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

assert_equals() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
    pass "$label"
  else
    fail "$label" "'$needle' not in output"
  fi
}

setup() {
  T=$(mktemp -d)
  cd "$T" || exit 1
}

teardown() {
  local tmp="$T"
  cd "$ORIG_DIR"
  rm -rf "$tmp"
  T=""
}

echo "metrics.sh unit tests"
echo "─────────────────────"

# T1: empty dir returns clean output and exit 0
setup
OUT=$(bash "$METRICS_SH")
assert_contains "empty: displays no telemetry notice" "$OUT" "No telemetry recorded yet"
JSON_OUT=$(bash "$METRICS_SH" --json)
assert_contains "empty: json has filter_savings" "$JSON_OUT" '"filter_savings"'
assert_equals "empty: json valid jq" "$(echo "$JSON_OUT" | jq -r '.filter_savings.commands_filtered')" "0"
teardown

# T2: filter stats calculation
setup
cat > .devflow-filter-stats.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","cmd":"git status","raw_chars":1000,"kept_chars":200,"raw_lines":20,"kept_lines":4}
{"ts":"2026-05-01T10:01:00Z","cmd":"flutter test","raw_chars":3000,"kept_chars":600,"raw_lines":50,"kept_lines":10}
JSONL
JSON_OUT=$(bash "$METRICS_SH" --json)
assert_equals "filter: 2 commands filtered" "$(echo "$JSON_OUT" | jq -r '.filter_savings.commands_filtered')" "2"
assert_equals "filter: raw chars sum" "$(echo "$JSON_OUT" | jq -r '.filter_savings.raw_chars')" "4000"
assert_equals "filter: kept chars sum" "$(echo "$JSON_OUT" | jq -r '.filter_savings.kept_chars')" "800"
assert_equals "filter: saved chars" "$(echo "$JSON_OUT" | jq -r '.filter_savings.saved_chars')" "3200"
assert_equals "filter: saved tokens (3200/4)" "$(echo "$JSON_OUT" | jq -r '.filter_savings.saved_tokens')" "800"
assert_equals "filter: reduction pct 80%" "$(echo "$JSON_OUT" | jq -r '.filter_savings.reduction_pct')" "80"
TEXT_OUT=$(bash "$METRICS_SH")
assert_contains "filter text: displays saved tokens" "$TEXT_OUT" "800 tokens"
teardown

# T3: cost & token telemetry calculation
setup
cat > .devflow-metrics.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","session":"s1","step":"task","feature":"auth","model":"claude-3-7-sonnet","input_tokens":1000,"output_tokens":200,"cache_creation_tokens":500,"cache_read_tokens":1500,"estimated_cost_usd":0.015}
{"ts":"2026-05-01T10:05:00Z","session":"s1","step":"plan","feature":"auth","model":"claude-3-7-sonnet","input_tokens":2000,"output_tokens":400,"cache_creation_tokens":0,"cache_read_tokens":2000,"estimated_cost_usd":0.025}
{"ts":"2026-05-01T10:10:00Z","session":"s2","step":"implement","feature":"checkout","model":"claude-3-7-sonnet","input_tokens":5000,"output_tokens":1000,"cache_creation_tokens":1000,"cache_read_tokens":4000,"estimated_cost_usd":0.060}
JSONL
JSON_OUT=$(bash "$METRICS_SH" --json)
assert_equals "metrics: total turns" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.total_turns')" "3"
assert_equals "metrics: unique sessions" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.total_sessions')" "2"
assert_equals "metrics: total tokens" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.total_tokens')" "18600"
assert_equals "metrics: total cost usd" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.total_cost_usd')" "0.1"
assert_equals "metrics: by feature count" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.by_feature | length')" "2"
assert_equals "metrics: top cost feature is checkout" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.by_feature[0].feature')" "checkout"
teardown

# T4: feature filter flag
setup
cat > .devflow-metrics.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","session":"s1","step":"task","feature":"auth","input_tokens":1000,"output_tokens":200,"cache_creation_tokens":0,"cache_read_tokens":0,"estimated_cost_usd":0.01}
{"ts":"2026-05-01T10:05:00Z","session":"s2","step":"implement","feature":"checkout","input_tokens":5000,"output_tokens":1000,"cache_creation_tokens":0,"cache_read_tokens":0,"estimated_cost_usd":0.05}
JSONL
FILTERED_JSON=$(bash "$METRICS_SH" --json --feature auth)
assert_equals "feature filter: only 1 turn" "$(echo "$FILTERED_JSON" | jq -r '.cost_telemetry.total_turns')" "1"
assert_equals "feature filter: cost is 0.01" "$(echo "$FILTERED_JSON" | jq -r '.cost_telemetry.total_cost_usd')" "0.01"
teardown

# T5: quality and pass@1 calculation
setup
cat > .devflow-observe.jsonl <<'JSONL'
{"event":"pre","tool_name":"Read","ts":"2026-05-01T10:00:00Z"}
{"event":"post","tool":"Read","is_error":false,"ts":"2026-05-01T10:00:01Z"}
{"event":"pre","tool_name":"Bash","ts":"2026-05-01T10:00:02Z"}
{"event":"post","tool":"Bash","is_error":true,"ts":"2026-05-01T10:00:03Z"}
{"event":"pre","tool_name":"Bash","ts":"2026-05-01T10:00:04Z"}
{"event":"post","tool":"Bash","is_error":false,"ts":"2026-05-01T10:00:05Z"}
JSONL
cat > .devflow-learnings.jsonl <<'JSONL'
{"type":"retry_loop","tool":"Bash","count":2,"ts":"2026-05-01T10:00:03Z"}
JSONL
JSON_OUT=$(bash "$METRICS_SH" --json)
assert_equals "quality: total calls" "$(echo "$JSON_OUT" | jq -r '.quality.total_tool_calls')" "3"
assert_equals "quality: failed calls" "$(echo "$JSON_OUT" | jq -r '.quality.failed_tool_calls')" "1"
assert_equals "quality: pass@1 rate 66.7%" "$(echo "$JSON_OUT" | jq -r '.quality.pass_at_1_rate')" "66.7"
assert_equals "quality: retry loops" "$(echo "$JSON_OUT" | jq -r '.quality.retry_loops_detected')" "1"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
