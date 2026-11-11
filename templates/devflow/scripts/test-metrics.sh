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

# T5b: re-reads, unstamped checks, calls per step
setup
cat > .devflow-observe.jsonl <<'JSONL'
{"event":"pre","tool":"Read","kind":"read","session":"s1","step":"devflow.test","read":"src/a.ts","ts":"2026-05-01T10:00:00Z"}
{"event":"pre","tool":"Read","kind":"read","session":"s1","step":"devflow.test","read":"src/a.ts","ts":"2026-05-01T10:00:01Z"}
{"event":"pre","tool":"Read","kind":"read","session":"s2","step":"devflow.ship","read":"src/a.ts","ts":"2026-05-01T10:00:02Z"}
{"event":"pre","tool":"Bash","kind":"shell","session":"s1","step":"devflow.test","cmd":"pnpm --filter web test","ts":"2026-05-01T10:00:03Z"}
{"event":"pre","tool":"Bash","kind":"shell","session":"s1","step":"devflow.test","cmd":"bash verify-stamp.sh run test -- pnpm test","ts":"2026-05-01T10:00:04Z"}
{"event":"pre","tool":"Bash","kind":"shell","session":"s1","step":"devflow.test","cmd":"git status","ts":"2026-05-01T10:00:05Z"}
JSONL
JSON_OUT=$(bash "$METRICS_SH" --json)
assert_equals "quality: duplicate reads (same session only)" "$(echo "$JSON_OUT" | jq -r '.quality.duplicate_reads')" "1"
assert_equals "quality: unstamped checks" "$(echo "$JSON_OUT" | jq -r '.quality.unstamped_checks')" "1"
assert_equals "quality: busiest step" "$(echo "$JSON_OUT" | jq -r '.quality.calls_by_step[0] | "\(.name)=\(.count)"')" "devflow.test=5"
teardown

# T6: .devflow-metrics/ folder — commands, context, tools, subagents, usage, --since
setup
mkdir .devflow-metrics
cat > .devflow-metrics/turns.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","session":"s1","command":"plan","feature":"cards","duration_sec":30,"input_tokens":10,"output_tokens":100,"cache_creation_tokens":0,"cache_read_tokens":900,"context_tokens":40000,"peak_context_tokens":50000,"tool_calls":{"Read":3},"estimated_cost_usd":0.01}
{"ts":"2026-05-02T10:00:00Z","session":"s1","command":"plan","feature":"cards","duration_sec":90,"input_tokens":10,"output_tokens":100,"cache_creation_tokens":0,"cache_read_tokens":900,"context_tokens":60000,"peak_context_tokens":70000,"tool_calls":{"Read":1},"estimated_cost_usd":0.02}
{"ts":"2026-05-03T10:00:00Z","session":"s2","command":"ship","feature":"cards","duration_sec":10,"input_tokens":5,"output_tokens":5,"cache_creation_tokens":0,"cache_read_tokens":0,"context_tokens":10000}
JSONL
cat > .devflow-metrics/tools.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","tool":"Read","kind":"read","is_error":false,"duration_ms":100,"output_tokens_est":500}
{"ts":"2026-05-01T10:00:01Z","tool":"Read","kind":"read","is_error":true,"duration_ms":300,"output_tokens_est":0}
{"ts":"2026-05-01T10:00:02Z","tool":"Skill","kind":"other","skill":"devflow:devflow-plan","is_error":false}
{"ts":"2026-05-01T10:00:03Z","tool":"mcp__context7__resolve-library-id","kind":"other","mcp_server":"context7","is_error":false}
JSONL
cat > .devflow-metrics/context.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","hook":"session-start","est_tokens":150}
{"ts":"2026-05-01T10:00:00Z","hook":"session-start-learnings","est_tokens":400}
{"ts":"2026-05-02T10:00:00Z","hook":"session-start","est_tokens":150}
JSONL
cat > .devflow-metrics/sessions.jsonl <<'JSONL'
{"ts":"2026-05-01T09:59:00Z","event":"session_start","session":"s1","host":"claude","source":"startup","plugin_version":"2.0.0"}
{"ts":"2026-05-02T09:00:00Z","event":"compact","session":"s1","trigger":"auto","context_tokens":160000,"tool_calls_in_session":80}
JSONL
cat > .devflow-metrics/subagents.jsonl <<'JSONL'
{"ts":"2026-05-03T10:00:00Z","agent_type":"code-reviewer","command":"ship","input_tokens":100,"output_tokens":100,"duration_ms":20000,"estimated_cost_usd":0.005}
JSONL
cat > .devflow-metrics/prompts.jsonl <<'JSONL'
{"ts":"2026-05-01T10:00:00Z","est_tokens":10,"slash_command":"devflow:devflow-plan","command":"plan"}
{"ts":"2026-05-02T10:00:00Z","est_tokens":30}
JSONL
JSON_OUT=$(bash "$METRICS_SH" --json)
assert_equals "folder: turns read from .devflow-metrics/" "$(echo "$JSON_OUT" | jq -r '.cost_telemetry.total_turns')" "3"
assert_equals "commands: plan first by total duration" "$(echo "$JSON_OUT" | jq -r '.commands[0].command')" "plan"
assert_equals "commands: plan avg duration" "$(echo "$JSON_OUT" | jq -r '.commands[0].avg_duration_sec')" "60"
assert_equals "commands: plan avg context" "$(echo "$JSON_OUT" | jq -r '.commands[0].avg_context_tokens')" "50000"
assert_equals "commands: ship subagent runs" "$(echo "$JSON_OUT" | jq -r '.commands[] | select(.command=="ship") | .subagent_runs')" "1"
assert_equals "context: peak" "$(echo "$JSON_OUT" | jq -r '.context.peak_context_tokens')" "70000"
assert_equals "context: auto compactions" "$(echo "$JSON_OUT" | jq -r '.context.auto_compactions')" "1"
assert_equals "context: injected total" "$(echo "$JSON_OUT" | jq -r '.context.injected_total_tokens')" "700"
assert_equals "context: top injector" "$(echo "$JSON_OUT" | jq -r '.context.injected_by_hook[0].hook')" "session-start-learnings"
assert_equals "tools: Read error pct" "$(echo "$JSON_OUT" | jq -r '.tools.by_tool[] | select(.tool=="Read") | .error_pct')" "50"
assert_equals "tools: Read avg ms" "$(echo "$JSON_OUT" | jq -r '.tools.by_tool[] | select(.tool=="Read") | .avg_ms')" "200"
assert_equals "tools: skill counted" "$(echo "$JSON_OUT" | jq -r '.tools.skills[0].name')" "devflow:devflow-plan"
assert_equals "tools: mcp server counted" "$(echo "$JSON_OUT" | jq -r '.tools.mcp_servers[0].name')" "context7"
assert_equals "usage: slash command pct" "$(echo "$JSON_OUT" | jq -r '.usage.slash_command_pct')" "50"
assert_equals "usage: plugin version" "$(echo "$JSON_OUT" | jq -r '.usage.plugin_versions[0].name')" "2.0.0"
SINCE_JSON=$(bash "$METRICS_SH" --json --since 2026-05-02)
assert_equals "since: drops older turns" "$(echo "$SINCE_JSON" | jq -r '.cost_telemetry.total_turns')" "2"
TEXT_OUT=$(bash "$METRICS_SH")
assert_contains "text: commands section" "$TEXT_OUT" "Commands (duration"
assert_contains "text: context section" "$TEXT_OUT" "Context Window & Memory"
assert_contains "text: subagents line" "$TEXT_OUT" "code-reviewer: 1 runs"
teardown

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
