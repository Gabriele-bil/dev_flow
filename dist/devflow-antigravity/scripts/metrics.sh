#!/bin/bash
# metrics.sh — DevFlow Telemetry & Metrics Dashboard.
# Aggregates bash filter token savings, estimated cost per feature, pass@k success rate,
# and step durations from local telemetry files.
#
# Usage:
#   bash metrics.sh [--json] [--feature <name>]
#
# Exit codes:
#   0: Success (metrics displayed or empty state reported)
#   1: Invalid argument or fatal error

set -euo pipefail

FORMAT="text"
FEATURE_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      FORMAT="json"
      shift
      ;;
    --feature)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --feature requires a name" >&2
        exit 1
      fi
      FEATURE_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: bash metrics.sh [--json] [--feature <name>]"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }

FILTER_STATS_FILE="${DEVFLOW_FILTER_STATS:-.devflow-filter-stats.jsonl}"
METRICS_LOG_FILE="${DEVFLOW_METRICS_LOG:-.devflow-metrics.jsonl}"
OBSERVE_LOG_FILE=".devflow-observe.jsonl"
LEARNINGS_FILE=".devflow-learnings.jsonl"
TEST_SUMMARY_FILE=".devflow-test-summary.json"

# ── 1. Filter Savings Telemetry (.devflow-filter-stats.jsonl) ────────────────
FILTER_JSON=$(
  if [ -f "$FILTER_STATS_FILE" ] && [ -s "$FILTER_STATS_FILE" ]; then
    jq -s '
      if length == 0 then
        {commands_filtered: 0, raw_chars: 0, kept_chars: 0, saved_chars: 0, saved_tokens: 0, reduction_pct: 0}
      else
        (map(.raw_chars // 0) | add // 0) as $raw |
        (map(.kept_chars // 0) | add // 0) as $kept |
        ($raw - $kept) as $saved |
        {
          commands_filtered: length,
          raw_chars: $raw,
          kept_chars: $kept,
          saved_chars: (if $saved > 0 then $saved else 0 end),
          saved_tokens: (if $saved > 0 then (($saved / 4) | floor) else 0 end),
          reduction_pct: (if $raw > 0 then (((( $raw - $kept ) / $raw) * 1000 | round) / 10) else 0 end)
        }
      end
    ' "$FILTER_STATS_FILE" 2>/dev/null || echo '{"commands_filtered": 0, "raw_chars": 0, "kept_chars": 0, "saved_chars": 0, "saved_tokens": 0, "reduction_pct": 0}'
  else
    echo '{"commands_filtered": 0, "raw_chars": 0, "kept_chars": 0, "saved_chars": 0, "saved_tokens": 0, "reduction_pct": 0}'
  fi
)

# ── 2. Costs & Token Telemetry (.devflow-metrics.jsonl) ───────────────────────
METRICS_JSON=$(
  if [ -f "$METRICS_LOG_FILE" ] && [ -s "$METRICS_LOG_FILE" ]; then
    jq -s --arg feat "$FEATURE_FILTER" '
      (if $feat != "" then map(select(.feature == $feat)) else . end) as $entries |
      if ($entries | length) == 0 then
        {
          total_turns: 0,
          total_sessions: 0,
          input_tokens: 0,
          output_tokens: 0,
          cache_creation_tokens: 0,
          cache_read_tokens: 0,
          total_tokens: 0,
          cache_hit_pct: 0,
          total_cost_usd: 0,
          avg_cost_per_session: 0,
          by_feature: [],
          by_step: []
        }
      else
        ($entries | length) as $turns |
        ($entries | map(.session // empty) | unique | length) as $sessions_raw |
        (if $sessions_raw > 0 then $sessions_raw else 1 end) as $sessions |
        ($entries | map(.input_tokens // 0) | add // 0) as $in_tok |
        ($entries | map(.output_tokens // 0) | add // 0) as $out_tok |
        ($entries | map(.cache_creation_tokens // 0) | add // 0) as $cache_create |
        ($entries | map(.cache_read_tokens // 0) | add // 0) as $cache_read |
        ($in_tok + $out_tok + $cache_create + $cache_read) as $total_tok |
        ($in_tok + $cache_create + $cache_read) as $total_prompt_tok |
        (if $total_prompt_tok > 0 then (((($cache_read / $total_prompt_tok) * 1000) | round) / 10) else 0 end) as $cache_pct |
        ($entries | map(.estimated_cost_usd // 0) | add // 0) as $cost |
        {
          total_turns: $turns,
          total_sessions: $sessions,
          input_tokens: $in_tok,
          output_tokens: $out_tok,
          cache_creation_tokens: $cache_create,
          cache_read_tokens: $cache_read,
          total_tokens: $total_tok,
          cache_hit_pct: $cache_pct,
          total_cost_usd: (((($cost * 10000) | round) / 10000)),
          avg_cost_per_session: (if $sessions > 0 then ((((($cost / $sessions) * 10000) | round) / 10000)) else 0 end),
          by_feature: (
            $entries
            | group_by(.feature // "unassigned")
            | map({
                feature: (.[0].feature // "unassigned"),
                turns: length,
                tokens: (map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // 0),
                cost_usd: ((((map(.estimated_cost_usd // 0) | add // 0) * 10000) | round) / 10000)
              })
            | sort_by(.cost_usd) | reverse
          ),
          by_step: (
            $entries
            | group_by(.step // "unknown")
            | map({
                step: (.[0].step // "unknown"),
                turns: length,
                tokens: (map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // 0),
                cost_usd: ((((map(.estimated_cost_usd // 0) | add // 0) * 10000) | round) / 10000)
              })
            | sort_by(.turns) | reverse
          )
        }
      end
    ' "$METRICS_LOG_FILE" 2>/dev/null || echo '{"total_turns":0,"total_sessions":0,"input_tokens":0,"output_tokens":0,"cache_creation_tokens":0,"cache_read_tokens":0,"total_tokens":0,"cache_hit_pct":0,"total_cost_usd":0,"avg_cost_per_session":0,"by_feature":[],"by_step":[]}'
  else
    echo '{"total_turns":0,"total_sessions":0,"input_tokens":0,"output_tokens":0,"cache_creation_tokens":0,"cache_read_tokens":0,"total_tokens":0,"cache_hit_pct":0,"total_cost_usd":0,"avg_cost_per_session":0,"by_feature":[],"by_step":[]}'
  fi
)

# ── 3. Quality & Stability (.devflow-observe.jsonl & .devflow-learnings.jsonl) ──
QUALITY_JSON=$(
  TOTAL_CALLS=0
  FAILED_CALLS=0
  RETRY_LOOPS=0

  if [ -f "$OBSERVE_LOG_FILE" ] && [ -s "$OBSERVE_LOG_FILE" ]; then
    OBS_STATS=$(jq -s '
      [ .[] | select(.event == "post") ] as $posts |
      {
        total: ($posts | length),
        failed: ($posts | map(select(.is_error == true)) | length)
      }
    ' "$OBSERVE_LOG_FILE" 2>/dev/null || echo '{"total":0,"failed":0}')
    TOTAL_CALLS=$(printf '%s' "$OBS_STATS" | jq -r '.total // 0')
    FAILED_CALLS=$(printf '%s' "$OBS_STATS" | jq -r '.failed // 0')
  fi

  if [ -f "$LEARNINGS_FILE" ] && [ -s "$LEARNINGS_FILE" ]; then
    RETRY_LOOPS=$(jq -s 'map(select(.type == "retry_loop")) | length' "$LEARNINGS_FILE" 2>/dev/null || echo 0)
  fi

  TEST_RATE=null
  if [ -f "$TEST_SUMMARY_FILE" ] && [ -s "$TEST_SUMMARY_FILE" ]; then
    TEST_RATE=$(jq 'if (.total // 0) > 0 then ((((.passed // 0) / .total) * 1000 | round) / 10) else null end' "$TEST_SUMMARY_FILE" 2>/dev/null || echo null)
  fi

  jq -n \
    --argjson total "$TOTAL_CALLS" \
    --argjson failed "$FAILED_CALLS" \
    --argjson retries "$RETRY_LOOPS" \
    --argjson test_rate "$TEST_RATE" \
    '{
      total_tool_calls: $total,
      failed_tool_calls: $failed,
      pass_at_1_rate: (if $total > 0 then ((((($total - $failed) / $total) * 1000) | round) / 10) else 100.0 end),
      retry_loops_detected: $retries,
      test_suite_pass_pct: $test_rate
    }'
)

# ── 4. Unified Payload ────────────────────────────────────────────────────────
PAYLOAD=$(
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg feature "$FEATURE_FILTER" \
    --argjson filter "$FILTER_JSON" \
    --argjson metrics "$METRICS_JSON" \
    --argjson quality "$QUALITY_JSON" \
    '{
      ts: $ts,
      filter: (if $feature != "" then $feature else null end),
      filter_savings: $filter,
      cost_telemetry: $metrics,
      quality: $quality
    }'
)

if [ "$FORMAT" = "json" ]; then
  printf '%s\n' "$PAYLOAD"
  exit 0
fi

# ── 5. Human-Readable Terminal Dashboard ──────────────────────────────────────
echo "========================================================================"
echo "                 🚀 DevFlow Telemetry & Metrics Dashboard"
echo "========================================================================"

HAS_ANY=0

CMD_COUNT=$(printf '%s' "$PAYLOAD" | jq -r '.filter_savings.commands_filtered // 0')
if [ "$CMD_COUNT" -gt 0 ]; then
  HAS_ANY=1
  RAW_C=$(printf '%s' "$PAYLOAD" | jq -r '.filter_savings.raw_chars // 0')
  KEPT_C=$(printf '%s' "$PAYLOAD" | jq -r '.filter_savings.kept_chars // 0')
  SAVED_C=$(printf '%s' "$PAYLOAD" | jq -r '.filter_savings.saved_chars // 0')
  SAVED_TOK=$(printf '%s' "$PAYLOAD" | jq -r '.filter_savings.saved_tokens // 0')
  REDUC_PCT=$(printf '%s' "$PAYLOAD" | jq -r '.filter_savings.reduction_pct // 0')

  echo ""
  echo "🛡️  Token Savings (post-bash-output-filter)"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Commands Filtered:   %s\n' "$CMD_COUNT"
  printf '  Raw Context Output:  %s chars\n' "$RAW_C"
  printf '  Retained Context:    %s chars\n' "$KEPT_C"
  printf '  Saved Context:       %s chars (~%s tokens)\n' "$SAVED_C" "$SAVED_TOK"
  printf '  Context Reduction:   %s%%\n' "$REDUC_PCT"
fi

TURNS=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.total_turns // 0')
if [ "$TURNS" -gt 0 ]; then
  HAS_ANY=1
  SESSIONS=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.total_sessions // 0')
  TOT_TOK=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.total_tokens // 0')
  IN_TOK=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.input_tokens // 0')
  OUT_TOK=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.output_tokens // 0')
  CACHE_R=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.cache_read_tokens // 0')
  CACHE_HIT=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.cache_hit_pct // 0')
  COST=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.total_cost_usd // 0')
  AVG_COST=$(printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.avg_cost_per_session // 0')

  echo ""
  echo "💰 Token & Cost Telemetry (stop-metrics.sh est.)"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Sessions Tracked:    %s (Total Turns: %s)\n' "$SESSIONS" "$TURNS"
  printf '  Total Tokens:        %s (In: %s | Out: %s | CacheRead: %s)\n' "$TOT_TOK" "$IN_TOK" "$OUT_TOK" "$CACHE_R"
  printf '  Prompt Cache Ratio:  %s%%\n' "$CACHE_HIT"
  printf '  Total Estimated:     $%s USD (~$%s / session)\n' "$COST" "$AVG_COST"

  FEAT_LEN=$(printf '%s' "$PAYLOAD" | jq '.cost_telemetry.by_feature | length')
  if [ "$FEAT_LEN" -gt 0 ]; then
    echo ""
    echo "  Breakdown by Feature:"
    printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.by_feature[] | "    • " + (.feature) + ": $" + (.cost_usd | tostring) + " USD (" + (.turns | tostring) + " turns, " + (.tokens | tostring) + " tokens)"'
  fi

  STEP_LEN=$(printf '%s' "$PAYLOAD" | jq '.cost_telemetry.by_step | length')
  if [ "$STEP_LEN" -gt 0 ]; then
    echo ""
    echo "  Breakdown by Step:"
    printf '%s' "$PAYLOAD" | jq -r '.cost_telemetry.by_step[] | "    • " + (.step) + ": " + (.turns | tostring) + " turns (~" + (.tokens | tostring) + " tokens)"'
  fi
fi

TOOL_CALLS=$(printf '%s' "$PAYLOAD" | jq -r '.quality.total_tool_calls // 0')
RETRY_COUNT=$(printf '%s' "$PAYLOAD" | jq -r '.quality.retry_loops_detected // 0')
if [ "$TOOL_CALLS" -gt 0 ] || [ "$RETRY_COUNT" -gt 0 ]; then
  HAS_ANY=1
  ERR_CALLS=$(printf '%s' "$PAYLOAD" | jq -r '.quality.failed_tool_calls // 0')
  PASS_RATE=$(printf '%s' "$PAYLOAD" | jq -r '.quality.pass_at_1_rate // 100')

  echo ""
  echo "🎯 Quality & Stability (pass@1 / stability)"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Tool Invocations:    %s (Errors: %s)\n' "$TOOL_CALLS" "$ERR_CALLS"
  printf '  First-Pass Success:  %s%% pass@1\n' "$PASS_RATE"
  printf '  Detected Retry Loops: %s\n' "$RETRY_COUNT"

  TEST_PCT=$(printf '%s' "$PAYLOAD" | jq -r '.quality.test_suite_pass_pct // empty')
  if [ -n "$TEST_PCT" ]; then
    printf '  Test Suite Success:  %s%%\n' "$TEST_PCT"
  fi
fi

if [ "$HAS_ANY" -eq 0 ]; then
  echo ""
  echo "ℹ️  No telemetry recorded yet in this workspace."
  echo "Telemetry is automatically generated during DevFlow runs via:"
  echo "  • post-bash-output-filter.sh (.devflow-filter-stats.jsonl)"
  echo "  • stop-metrics.sh            (.devflow-metrics.jsonl)"
  echo "  • observe.sh                 (.devflow-observe.jsonl)"
fi

echo "========================================================================"
exit 0
