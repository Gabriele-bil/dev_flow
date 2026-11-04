#!/bin/bash
# metrics.sh — DevFlow Telemetry & Metrics Dashboard.
# Aggregates the local telemetry folder (.devflow-metrics/, gitignored) into one
# report: bash-filter token savings, tokens/cost per feature and step, command
# durations, context-window use and compactions, context injected by devflow
# hooks, tool/skill/MCP/subagent usage, sessions, pass@1 and retry loops.
# Schema of every file: skills/devflow-metrics/references/telemetry-schema.md
#
# Usage:
#   bash metrics.sh [--json] [--feature <name>] [--since <YYYY-MM-DD>]
#
# Reads DEVFLOW_METRICS_DIR (default .devflow-metrics); pre-2.1 root-level logs
# (.devflow-metrics.jsonl, .devflow-filter-stats.jsonl) are read when the folder
# has no counterpart yet.
#
# Exit codes:
#   0: Success (metrics displayed or empty state reported)
#   1: Invalid argument or fatal error

set -euo pipefail

FORMAT="text"
FEATURE_FILTER=""
SINCE=""

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
    --since)
      if [[ -z "${2:-}" ]]; then
        echo "ERROR: --since requires a date (YYYY-MM-DD)" >&2
        exit 1
      fi
      SINCE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: bash metrics.sh [--json] [--feature <name>] [--since <YYYY-MM-DD>]"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }

METRICS_DIR="${DEVFLOW_METRICS_DIR:-.devflow-metrics}"
OBSERVE_LOG_FILE=".devflow-observe.jsonl"
LEARNINGS_FILE=".devflow-learnings.jsonl"
TEST_SUMMARY_FILE=".devflow-test-summary.json"

# log_path <name> <legacy-root-file> [override] — folder file, else legacy root file
log_path() {
  local name="$1" legacy="$2" override="${3:-}"
  if [ -n "$override" ]; then printf '%s' "$override"; return 0; fi
  if [ -f "$METRICS_DIR/$name.jsonl" ] || [ -f "$METRICS_DIR/$name.jsonl.1" ] || [ -z "$legacy" ] || [ ! -f "$legacy" ]; then
    printf '%s' "$METRICS_DIR/$name.jsonl"
  else
    printf '%s' "$legacy"
  fi
}

# read_log <path> [feature-filtered] — rotated + current rows as one JSON array,
# filtered by --since (and by --feature when the second arg is "feature").
read_log() {
  local path="$1" by_feature="${2:-}" feat=""
  [ "$by_feature" = "feature" ] && feat="$FEATURE_FILTER"
  { [ -f "$path.1" ] && cat "$path.1"; [ -f "$path" ] && cat "$path"; true; } 2>/dev/null \
    | jq -R 'fromjson? // empty' 2>/dev/null \
    | jq -s --arg since "$SINCE" --arg feat "$feat" '
        map(select(type == "object")
            | select($since == "" or (.ts // "") >= $since)
            | select($feat == "" or .feature == $feat))' 2>/dev/null || echo '[]'
}

# Rows go through temp files (--slurpfile): logs reach MBs, past ARG_MAX for --argjson
ROWS=$(mktemp -d 2>/dev/null || mktemp -d -t devflow-metrics)
trap 'rm -rf "$ROWS"' EXIT
read_log "$(log_path filter-stats .devflow-filter-stats.jsonl "${DEVFLOW_FILTER_STATS:-}")" > "$ROWS/filter.json"
read_log "$(log_path turns .devflow-metrics.jsonl "${DEVFLOW_METRICS_LOG:-}")" feature > "$ROWS/turns.json"
read_log "$METRICS_DIR/tools.jsonl" feature > "$ROWS/tools.json"
read_log "$METRICS_DIR/context.jsonl" > "$ROWS/context.json"
read_log "$METRICS_DIR/sessions.jsonl" > "$ROWS/sessions.json"
read_log "$METRICS_DIR/prompts.jsonl" feature > "$ROWS/prompts.json"
read_log "$METRICS_DIR/subagents.jsonl" feature > "$ROWS/subagents.json"


# ── 1. Filter Savings Telemetry (filter-stats.jsonl) ─────────────────────────
FILTER_JSON=$(jq '
  (map(.raw_chars // 0) | add // 0) as $raw
  | (map(.kept_chars // 0) | add // 0) as $kept
  | ($raw - $kept) as $saved
  | {
      commands_filtered: length,
      raw_chars: $raw,
      kept_chars: $kept,
      saved_chars: (if $saved > 0 then $saved else 0 end),
      saved_tokens: (if $saved > 0 then (($saved / 4) | floor) else 0 end),
      reduction_pct: (if $raw > 0 then (((($raw - $kept) / $raw) * 1000 | round) / 10) else 0 end)
    }' "$ROWS/filter.json")

# ── 2. Costs & Token Telemetry (turns.jsonl) ─────────────────────────────────
METRICS_JSON=$(jq '
  def r4: (. * 10000 | round) / 10000;
  def tok: (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0);
  . as $entries
  | ($entries | length) as $turns
  | ($entries | map(.session // empty) | unique | length) as $sessions_raw
  | (if $sessions_raw > 0 then $sessions_raw else 1 end) as $sessions
  | ($entries | map(.input_tokens // 0) | add // 0) as $in_tok
  | ($entries | map(.output_tokens // 0) | add // 0) as $out_tok
  | ($entries | map(.cache_creation_tokens // 0) | add // 0) as $cache_create
  | ($entries | map(.cache_read_tokens // 0) | add // 0) as $cache_read
  | ($in_tok + $cache_create + $cache_read) as $total_prompt_tok
  | ($entries | map(.estimated_cost_usd // 0) | add // 0) as $cost
  | {
      total_turns: $turns,
      total_sessions: (if $turns > 0 then $sessions else 0 end),
      input_tokens: $in_tok,
      output_tokens: $out_tok,
      cache_creation_tokens: $cache_create,
      cache_read_tokens: $cache_read,
      thinking_tokens: ($entries | map(.thinking_tokens // 0) | add // 0),
      total_tokens: ($in_tok + $out_tok + $cache_create + $cache_read),
      cache_hit_pct: (if $total_prompt_tok > 0 then (((($cache_read / $total_prompt_tok) * 1000) | round) / 10) else 0 end),
      total_cost_usd: ($cost | r4),
      avg_cost_per_session: (if $turns > 0 then (($cost / $sessions) | r4) else 0 end),
      by_feature: (
        $entries | group_by(.feature // "unassigned")
        | map({feature: (.[0].feature // "unassigned"), turns: length,
               tokens: (map(tok) | add // 0),
               cost_usd: ((map(.estimated_cost_usd // 0) | add // 0) | r4)})
        | sort_by(.cost_usd) | reverse),
      by_step: (
        $entries | group_by(.step // "unknown")
        | map({step: (.[0].step // "unknown"), turns: length,
               tokens: (map(tok) | add // 0),
               cost_usd: ((map(.estimated_cost_usd // 0) | add // 0) | r4)})
        | sort_by(.turns) | reverse),
      by_model: (
        $entries | group_by(.model // "unknown")
        | map({model: (.[0].model // "unknown"), turns: length,
               tokens: (map(tok) | add // 0),
               cost_usd: ((map(.estimated_cost_usd // 0) | add // 0) | r4)})
        | sort_by(.cost_usd) | reverse)
    }' "$ROWS/turns.json")

# ── 3. Commands: duration, tokens, cost, context per devflow command ────────
COMMANDS_JSON=$(jq -n --slurpfile turns "$ROWS/turns.json" --slurpfile subs "$ROWS/subagents.json" '
  def r4: (. * 10000 | round) / 10000;
  def r1: (. * 10 | round) / 10;
  def tok: (.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0);
  def pct($p): sort | if length == 0 then 0 else .[((length - 1) * $p | floor)] end;
  ($turns[0]) as $turns | ($subs[0]) as $subs |
  ($subs | group_by(.command // "none") | map({key: (.[0].command // "none"),
     value: {runs: length, tokens: (map(tok) | add // 0), cost: (map(.estimated_cost_usd // 0) | add // 0)}}) | from_entries) as $sub
  | $turns | group_by(.command // "none")
  | map((.[0].command // "none") as $c
      | (map(.duration_sec // 0)) as $d
      | {
          command: $c,
          turns: length,
          sessions: (map(.session // empty) | unique | length),
          total_duration_sec: ($d | add // 0),
          avg_duration_sec: (($d | add // 0) / length | r1),
          p50_duration_sec: ($d | pct(0.5)),
          p90_duration_sec: ($d | pct(0.9)),
          avg_tokens: ((map(tok) | add // 0) / length | floor),
          avg_output_tokens: ((map(.output_tokens // 0) | add // 0) / length | floor),
          avg_context_tokens: ((map(.context_tokens // 0) | add // 0) / length | floor),
          peak_context_tokens: (map(.peak_context_tokens // .context_tokens // 0) | max // 0),
          avg_tool_calls: ((map((.tool_calls // {}) | add // 0) | add // 0) / length | r1),
          compactions: (map(.compactions // 0) | add // 0),
          cost_usd: ((map(.estimated_cost_usd // 0) | add // 0) | r4),
          subagent_runs: ($sub[$c].runs // 0),
          subagent_tokens: ($sub[$c].tokens // 0),
          subagent_cost_usd: (($sub[$c].cost // 0) | r4)
        })
  | sort_by(.total_duration_sec) | reverse')

# ── 4. Context window & memory ───────────────────────────────────────────────
CONTEXT_JSON=$(jq -n --slurpfile turns "$ROWS/turns.json" --slurpfile ctx "$ROWS/context.json" --slurpfile sess "$ROWS/sessions.json" '
  ($turns[0]) as $turns | ($ctx[0]) as $ctx | ($sess[0]) as $sess |
  ([ $turns[] | .context_tokens // empty ]) as $c
  | ([ $sess[] | select(.event == "compact") ]) as $comp
  | {
      avg_context_tokens: (if ($c | length) > 0 then (($c | add) / ($c | length) | floor) else 0 end),
      peak_context_tokens: ([ $turns[] | .peak_context_tokens // .context_tokens // 0 ] | max // 0),
      cache_read_tokens: ([ $turns[] | .cache_read_tokens // 0 ] | add // 0),
      compactions: ($comp | length),
      auto_compactions: ($comp | map(select(.trigger == "auto")) | length),
      avg_context_at_compact: (if ($comp | length) > 0 then (($comp | map(.context_tokens // 0) | add) / ($comp | length) | floor) else 0 end),
      avg_tool_calls_before_compact: (if ($comp | length) > 0 then (($comp | map(.tool_calls_in_session // 0) | add) / ($comp | length) | floor) else 0 end),
      injected_total_tokens: ($ctx | map(.est_tokens // 0) | add // 0),
      injected_by_hook: ($ctx | group_by(.hook // "unknown")
        | map({hook: (.[0].hook // "unknown"), injections: length,
               total_tokens: (map(.est_tokens // 0) | add // 0),
               avg_tokens: ((map(.est_tokens // 0) | add // 0) / length | floor)})
        | sort_by(.total_tokens) | reverse)
    }')

# ── 5. Tools, skills, MCP, subagents ─────────────────────────────────────────
TOOLS_JSON=$(jq -n --slurpfile tools "$ROWS/tools.json" --slurpfile subs "$ROWS/subagents.json" '
  def r1: (. * 10 | round) / 10;
  def counts(f): map(f // empty) | group_by(.) | map({name: .[0], calls: length}) | sort_by(.calls) | reverse;
  ($tools[0]) as $tools | ($subs[0]) as $subs |
  {
    total_calls: ($tools | length),
    failed_calls: ($tools | map(select(.is_error == true)) | length),
    output_tokens_est: ($tools | map(.output_tokens_est // 0) | add // 0),
    by_tool: ($tools | group_by(.tool // "unknown")
      | map(([ .[] | .duration_ms // empty ]) as $d
          | {tool: (.[0].tool // "unknown"), calls: length,
             errors: (map(select(.is_error == true)) | length),
             error_pct: ((map(select(.is_error == true)) | length) * 100 / length | r1),
             avg_ms: (if ($d | length) > 0 then (($d | add) / ($d | length) | floor) else null end),
             total_ms: ($d | add // 0),
             output_tokens_est: (map(.output_tokens_est // 0) | add // 0)})
      | sort_by(.calls) | reverse),
    skills: ($tools | counts(.skill)),
    mcp_servers: ($tools | counts(.mcp_server)),
    subagent_calls: ($tools | counts(.subagent_type)),
    calls_from_subagents: ($tools | map(select((.agent_type // "") != "")) | length),
    subagents: {
      runs: ($subs | length),
      tokens: ($subs | map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // 0),
      cost_usd: ((($subs | map(.estimated_cost_usd // 0) | add // 0) * 10000 | round) / 10000),
      by_type: ($subs | group_by(.agent_type // "unknown")
        | map({agent_type: (.[0].agent_type // "unknown"), runs: length,
               avg_tokens: ((map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // 0) / length | floor),
               avg_duration_sec: ((map(.duration_ms // 0) | add // 0) / length / 1000 | r1)})
        | sort_by(.runs) | reverse)
    }
  }')

# ── 6. Usage: sessions, prompts, plugin versions ─────────────────────────────
USAGE_JSON=$(jq -n --slurpfile sess "$ROWS/sessions.json" --slurpfile prompts "$ROWS/prompts.json" '
  def counts(f): map(f // empty) | group_by(.) | map({name: .[0], count: length}) | sort_by(.count) | reverse;
  ($sess[0]) as $sess | ($prompts[0]) as $prompts |
  ([ $sess[] | select(.event == "session_start") ]) as $starts
  | {
      sessions_started: ($starts | length),
      by_source: ($starts | counts(.source)),
      by_host: ($starts | counts(.host)),
      plugin_versions: ($starts | counts(.plugin_version)),
      models: ($starts | counts(.model)),
      adapters: ($starts | counts(.adapter)),
      session_end_reasons: ([ $sess[] | select(.event == "session_end") ] | counts(.reason)),
      prompts: ($prompts | length),
      avg_prompt_tokens: (if ($prompts | length) > 0 then (($prompts | map(.est_tokens // 0) | add) / ($prompts | length) | floor) else 0 end),
      slash_command_pct: (if ($prompts | length) > 0 then ((($prompts | map(select((.slash_command // "") != "")) | length) * 1000 / ($prompts | length) | round) / 10) else 0 end),
      devflow_commands: ($prompts | counts(.command))
    }')

# ── 7. Quality & Stability (.devflow-observe.jsonl & .devflow-learnings.jsonl) ──
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

# ── 8. Unified Payload ────────────────────────────────────────────────────────
PAYLOAD=$(
  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg feature "$FEATURE_FILTER" \
    --arg since "$SINCE" \
    --arg dir "$METRICS_DIR" \
    --argjson filter "$FILTER_JSON" \
    --argjson metrics "$METRICS_JSON" \
    --argjson commands "$COMMANDS_JSON" \
    --argjson context "$CONTEXT_JSON" \
    --argjson tools "$TOOLS_JSON" \
    --argjson usage "$USAGE_JSON" \
    --argjson quality "$QUALITY_JSON" \
    '{
      ts: $ts,
      filter: (if $feature != "" then $feature else null end),
      since: (if $since != "" then $since else null end),
      metrics_dir: $dir,
      filter_savings: $filter,
      cost_telemetry: $metrics,
      commands: $commands,
      context: $context,
      tools: $tools,
      usage: $usage,
      quality: $quality
    }'
)

if [ "$FORMAT" = "json" ]; then
  printf '%s\n' "$PAYLOAD"
  exit 0
fi

# ── 9. Human-Readable Terminal Dashboard ──────────────────────────────────────
q() { printf '%s' "$PAYLOAD" | jq -r "$1"; }

echo "========================================================================"
echo "                 🚀 DevFlow Telemetry & Metrics Dashboard"
echo "========================================================================"

HAS_ANY=0

CMD_COUNT=$(q '.filter_savings.commands_filtered // 0')
if [ "$CMD_COUNT" -gt 0 ]; then
  HAS_ANY=1
  echo ""
  echo "🛡️  Token Savings (post-bash-output-filter)"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Commands Filtered:   %s\n' "$CMD_COUNT"
  printf '  Raw Context Output:  %s chars\n' "$(q '.filter_savings.raw_chars')"
  printf '  Retained Context:    %s chars\n' "$(q '.filter_savings.kept_chars')"
  printf '  Saved Context:       %s chars (~%s tokens)\n' "$(q '.filter_savings.saved_chars')" "$(q '.filter_savings.saved_tokens')"
  printf '  Context Reduction:   %s%%\n' "$(q '.filter_savings.reduction_pct')"
fi

TURNS=$(q '.cost_telemetry.total_turns // 0')
if [ "$TURNS" -gt 0 ]; then
  HAS_ANY=1
  echo ""
  echo "💰 Token & Cost Telemetry (stop-metrics.sh est.)"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Sessions Tracked:    %s (Total Turns: %s)\n' "$(q '.cost_telemetry.total_sessions')" "$TURNS"
  printf '  Total Tokens:        %s (In: %s | Out: %s | CacheRead: %s | Thinking: %s)\n' \
    "$(q '.cost_telemetry.total_tokens')" "$(q '.cost_telemetry.input_tokens')" "$(q '.cost_telemetry.output_tokens')" \
    "$(q '.cost_telemetry.cache_read_tokens')" "$(q '.cost_telemetry.thinking_tokens')"
  printf '  Prompt Cache Ratio:  %s%%\n' "$(q '.cost_telemetry.cache_hit_pct')"
  printf '  Total Estimated:     $%s USD (~$%s / session)\n' "$(q '.cost_telemetry.total_cost_usd')" "$(q '.cost_telemetry.avg_cost_per_session')"

  if [ "$(q '.cost_telemetry.by_feature | length')" -gt 0 ]; then
    echo ""
    echo "  Breakdown by Feature:"
    q '.cost_telemetry.by_feature[] | "    • " + (.feature) + ": $" + (.cost_usd | tostring) + " USD (" + (.turns | tostring) + " turns, " + (.tokens | tostring) + " tokens)"'
  fi

  if [ "$(q '.cost_telemetry.by_step | length')" -gt 0 ]; then
    echo ""
    echo "  Breakdown by Step:"
    q '.cost_telemetry.by_step[] | "    • " + (.step) + ": " + (.turns | tostring) + " turns (~" + (.tokens | tostring) + " tokens)"'
  fi

  echo ""
  echo "⏱️  Commands (duration · tokens · context per turn)"
  echo "────────────────────────────────────────────────────────────────────────"
  q '.commands[] | "    • " + .command + ": " + (.turns | tostring) + " turns, avg " + (.avg_duration_sec | tostring)
     + "s (p90 " + (.p90_duration_sec | tostring) + "s), ~" + (.avg_tokens | tostring) + " tok/turn, ctx ~"
     + (.avg_context_tokens | tostring) + ", $" + (.cost_usd | tostring)
     + (if .subagent_runs > 0 then " + subagents $" + (.subagent_cost_usd | tostring) + " (" + (.subagent_runs | tostring) + " runs)" else "" end)'
fi

if [ "$TURNS" -gt 0 ] || [ "$(q '.context.injected_by_hook | length')" -gt 0 ] || [ "$(q '.context.compactions')" -gt 0 ]; then
  HAS_ANY=1
  echo ""
  echo "🧠 Context Window & Memory"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Context per Turn:    avg %s tokens (peak %s)\n' "$(q '.context.avg_context_tokens')" "$(q '.context.peak_context_tokens')"
  printf '  Read from Cache:     %s tokens\n' "$(q '.context.cache_read_tokens')"
  printf '  Compactions:         %s (auto: %s, avg ctx at compact: %s, avg tool calls before: %s)\n' \
    "$(q '.context.compactions')" "$(q '.context.auto_compactions')" "$(q '.context.avg_context_at_compact')" "$(q '.context.avg_tool_calls_before_compact')"
  printf '  Injected by Hooks:   ~%s tokens\n' "$(q '.context.injected_total_tokens')"
  q '.context.injected_by_hook[] | "    • " + .hook + ": " + (.injections | tostring) + "× (~" + (.avg_tokens | tostring) + " tok each, ~" + (.total_tokens | tostring) + " total)"'
fi

if [ "$(q '.tools.total_calls')" -gt 0 ] || [ "$(q '.tools.subagents.runs')" -gt 0 ]; then
  HAS_ANY=1
  echo ""
  echo "🔧 Tools, Skills & Subagents"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Tool Calls:          %s (errors: %s, output fed back: ~%s tokens)\n' \
    "$(q '.tools.total_calls')" "$(q '.tools.failed_calls')" "$(q '.tools.output_tokens_est')"
  q '.tools.by_tool[:10][] | "    • " + .tool + ": " + (.calls | tostring) + " calls, " + (.error_pct | tostring) + "% err"
     + (if .avg_ms != null then ", avg " + (.avg_ms | tostring) + "ms" else "" end) + ", ~" + (.output_tokens_est | tostring) + " tok out"'
  if [ "$(q '.tools.skills | length')" -gt 0 ]; then
    echo "  Skills loaded:"
    q '.tools.skills[] | "    • " + .name + ": " + (.calls | tostring)'
  fi
  if [ "$(q '.tools.mcp_servers | length')" -gt 0 ]; then
    echo "  MCP servers:"
    q '.tools.mcp_servers[] | "    • " + .name + ": " + (.calls | tostring)'
  fi
  if [ "$(q '.tools.subagents.runs')" -gt 0 ]; then
    printf '  Subagents:           %s runs, %s tokens, $%s USD\n' \
      "$(q '.tools.subagents.runs')" "$(q '.tools.subagents.tokens')" "$(q '.tools.subagents.cost_usd')"
    q '.tools.subagents.by_type[] | "    • " + .agent_type + ": " + (.runs | tostring) + " runs, ~" + (.avg_tokens | tostring) + " tok, ~" + (.avg_duration_sec | tostring) + "s"'
  fi
fi

if [ "$(q '.usage.sessions_started')" -gt 0 ] || [ "$(q '.usage.prompts')" -gt 0 ]; then
  HAS_ANY=1
  echo ""
  echo "📈 Usage"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Sessions Started:    %s (%s)\n' "$(q '.usage.sessions_started')" "$(q '[.usage.by_source[] | .name + " " + (.count | tostring)] | join(", ")')"
  printf '  Hosts / Versions:    %s · %s\n' "$(q '[.usage.by_host[] | .name] | join(", ")')" "$(q '[.usage.plugin_versions[] | .name] | join(", ")')"
  printf '  Prompts:             %s (avg ~%s tok, %s%% slash commands)\n' "$(q '.usage.prompts')" "$(q '.usage.avg_prompt_tokens')" "$(q '.usage.slash_command_pct')"
  q '.usage.devflow_commands[] | "    • /devflow." + .name + ": " + (.count | tostring)'
fi

TOOL_CALLS=$(q '.quality.total_tool_calls // 0')
RETRY_COUNT=$(q '.quality.retry_loops_detected // 0')
if [ "$TOOL_CALLS" -gt 0 ] || [ "$RETRY_COUNT" -gt 0 ]; then
  HAS_ANY=1
  echo ""
  echo "🎯 Quality & Stability (pass@1 / stability)"
  echo "────────────────────────────────────────────────────────────────────────"
  printf '  Tool Invocations:    %s (Errors: %s)\n' "$TOOL_CALLS" "$(q '.quality.failed_tool_calls // 0')"
  printf '  First-Pass Success:  %s%% pass@1\n' "$(q '.quality.pass_at_1_rate // 100')"
  printf '  Detected Retry Loops: %s\n' "$RETRY_COUNT"

  TEST_PCT=$(q '.quality.test_suite_pass_pct // empty')
  if [ -n "$TEST_PCT" ]; then
    printf '  Test Suite Success:  %s%%\n' "$TEST_PCT"
  fi
fi

if [ "$HAS_ANY" -eq 0 ]; then
  echo ""
  echo "ℹ️  No telemetry recorded yet in this workspace."
  echo "Telemetry is generated automatically during DevFlow runs into $METRICS_DIR/ (gitignored):"
  echo "  • stop-metrics.sh            (turns.jsonl, timings.jsonl)"
  echo "  • observe.sh                 (tools.jsonl)"
  echo "  • metrics-collect.sh         (sessions.jsonl, prompts.jsonl, subagents.jsonl)"
  echo "  • post-bash-output-filter.sh (filter-stats.jsonl)"
  echo "  • lib/emit.sh                (context.jsonl)"
fi

echo "========================================================================"
exit 0
