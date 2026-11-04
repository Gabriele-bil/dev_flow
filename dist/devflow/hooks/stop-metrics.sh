#!/bin/bash
# stop-metrics.sh — Stop hook: per-turn usage, context, cost and timing,
# appended to .devflow-metrics/turns.jsonl and .devflow-metrics/timings.jsonl
# (gitignored folder; DEVFLOW_METRICS_LOG / DEVFLOW_TIMINGS_LOG override a file,
# DEVFLOW_METRICS_DIR=off disables both).
# Also triggers board.sh --sync --quiet when devflow/board/index.html exists.
# Async, no stdout.
#
# Per-turn usage: only the transcript bytes appended since the previous Stop
# are parsed (offset kept in .devflow-observe-state.json), so each row is this
# turn's usage — summing rows never double-counts. Deduped by message id.
# Claude Code transcript: assistant entries with .message.usage.
# Antigravity transcript: PLANNER_RESPONSE entries with input/output/
# cache_read_tokens (model from the Stop payload; no price → cost omitted).
# Beyond tokens each row carries: context_tokens (prompt size of the last model
# call = context window in use), peak_context_tokens, thinking_tokens,
# api_calls, tool_calls by name, skills loaded, slash commands typed,
# compactions. Duration: UserPromptSubmit mark (metrics-collect.sh prompt), else
# first transcript timestamp of the turn, else first tool call of the turn.
#
# Cost: lib/payload.sh df_estimate_cost (USD/MTok per model family; local
# estimate for relative tracking, not billing; DEVFLOW_PRICING_JSON overrides).

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0
RAW="$DF_RAW"

SCRIPT_DIR="$HOOK_DIR"
WORKSPACE_ROOT="$DF_WORKSPACE"
LOG_FILE="${DEVFLOW_METRICS_LOG:-}"
TIMINGS_FILE="${DEVFLOW_TIMINGS_LOG:-}"
if df_metrics_dir; then
  LOG_FILE="${LOG_FILE:-$DF_METRICS_DIR/turns.jsonl}"
  TIMINGS_FILE="${TIMINGS_FILE:-$DF_METRICS_DIR/timings.jsonl}"
else
  LOG_FILE="off" TIMINGS_FILE="off"
fi

SESSION="$DF_SESSION"

STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$WORKSPACE_ROOT/.devflow-observe-state.json}"
STEP=""
FEATURE=""
ACTIVE_FEATURE=""
ACTIVE_CMD=""
STARTED_AT=""
STARTED_EPOCH=0
PROMPT_MS=0
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  ACTIVE_FEATURE=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE="$ACTIVE_FEATURE"
fi
if [ -f "$OBS_STATE" ]; then
  ACTIVE_CMD=$(jq -r '.active_command // empty' "$OBS_STATE" 2>/dev/null) || true
  STARTED_AT=$(jq -r '.turn_started_at // empty' "$OBS_STATE" 2>/dev/null) || true
  STARTED_EPOCH=$(jq -r '.turn_started_epoch // 0' "$OBS_STATE" 2>/dev/null) || STARTED_EPOCH=0
  PROMPT_MS=$(jq -r '.prompt_started_ms // 0' "$OBS_STATE" 2>/dev/null) || PROMPT_MS=0
fi
[[ "$PROMPT_MS" =~ ^[0-9]+$ ]] || PROMPT_MS=0

# Normalize command name (task, clarify, plan, analyze, implement, beautify, test, ship, pr, hotfix)
COMMAND="$ACTIVE_CMD"
if [ -z "$COMMAND" ] && [ -n "$STEP" ]; then
  case "$STEP" in
    devflow.*) COMMAND="${STEP#devflow.}" ;;
    task|clarify|plan|analyze|implement|beautify|test|ship|pr|hotfix) COMMAND="$STEP" ;;
  esac
fi

ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true
ENDED_EPOCH=$(date +%s 2>/dev/null || echo 0)
[ -z "$STARTED_AT" ] && STARTED_AT="$ENDED_AT"

DURATION_SEC=0
if [ "${STARTED_EPOCH:-0}" -gt 0 ] && [ "${ENDED_EPOCH:-0}" -ge "${STARTED_EPOCH:-0}" ]; then
  DURATION_SEC=$(( ENDED_EPOCH - STARTED_EPOCH ))
elif [ "$STARTED_AT" != "$ENDED_AT" ]; then
  # Parse ISO-8601 fallback via jq fromdateiso8601
  DURATION_SEC=$(jq -n --arg s "$STARTED_AT" --arg e "$ENDED_AT" \
    '((($e | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) - ($s | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) | if . > 0 then . else 0 end)' \
    2>/dev/null || echo 0)
  [ -z "$DURATION_SEC" ] && DURATION_SEC=0
fi
# Prompt-submit mark is the precise turn start (covers thinking before the first tool)
NOW_MS=$(df_now_ms)
[[ "$NOW_MS" =~ ^[0-9]+$ ]] || NOW_MS=$(( ENDED_EPOCH * 1000 ))
DURATION_MS=$(( DURATION_SEC * 1000 ))
if [ "$PROMPT_MS" -gt 0 ] && [ "$NOW_MS" -ge "$PROMPT_MS" ]; then
  DURATION_MS=$(( NOW_MS - PROMPT_MS ))
  DURATION_SEC=$(( (DURATION_MS + 500) / 1000 ))
fi
EXTRA_JSON='{}'
PLUGIN_VERSION=$(df_plugin_version)

TRANSCRIPT="$DF_TRANSCRIPT"

INPUT_TOK=0
OUTPUT_TOK=0
CACHE_CREATE_TOK=0
CACHE_READ_TOK=0
MODEL=""
COST=null
HAS_TRANSCRIPT_USAGE=0

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && [ "$LOG_FILE" != "off" ]; then
  MAX_BYTES="${DEVFLOW_METRICS_TAIL_BYTES:-2000000}"
  SIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null | tr -d '[:space:]')
  [ -z "$SIZE" ] && SIZE=0
  PREV_PATH=""
  PREV_OFF=0
  if [ -f "$OBS_STATE" ]; then
    PREV_PATH=$(jq -r '.metrics_transcript // empty' "$OBS_STATE" 2>/dev/null) || true
    PREV_OFF=$(jq -r '.metrics_offset // 0' "$OBS_STATE" 2>/dev/null) || PREV_OFF=0
  fi
  [[ "$PREV_OFF" =~ ^[0-9]+$ ]] || PREV_OFF=0
  # New transcript or truncated file → start over
  if [ "$PREV_PATH" != "$TRANSCRIPT" ] || [ "$PREV_OFF" -gt "$SIZE" ]; then PREV_OFF=0; fi
  START=$PREV_OFF
  [ $((SIZE - START)) -gt "$MAX_BYTES" ] && START=$((SIZE - MAX_BYTES))
  df_json_update "$OBS_STATE" '.metrics_transcript = $t | .metrics_offset = $o' \
    --arg t "$TRANSCRIPT" --argjson o "$SIZE"

  # Lines appended since the last Stop; a partial first line (mid-offset
  # START from the size cap) fails to parse and is skipped by fromjson?.
  USAGE_JSON=$(tail -c +$((START + 1)) "$TRANSCRIPT" 2>/dev/null | head -c $((SIZE - START)) \
    | jq -R 'fromjson? // empty' 2>/dev/null | jq -s --arg agy_model "$(printf '%s' "$RAW" | jq -r '.modelName // empty' 2>/dev/null)" '
    def ms: (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601? // null) as $s
      | if $s == null then null else $s * 1000 + ((capture("\\.(?<f>[0-9]{1,3})") | .f + "00" | .[0:3] | tonumber) // 0) end;
    ( [ .[] | select(.type == "assistant" and .message.usage != null) ]
      | unique_by(.message.id // (.message.usage | tostring))
      | map(.message.usage as $u
          | {in: ($u.input_tokens // 0), out: ($u.output_tokens // 0),
             cw: ($u.cache_creation_input_tokens // 0), cr: ($u.cache_read_input_tokens // 0),
             think: ($u.output_tokens_details.thinking_tokens // 0),
             web: ($u.server_tool_use.web_search_requests // 0),
             side: (.isSidechain // false), model: (.message.model // "")}) ) as $cc
    | ( [ .[] | select(.type == "PLANNER_RESPONSE" and (.input_tokens != null or .output_tokens != null)) ]
      | map({in: (.input_tokens // 0), out: (.output_tokens // 0), cw: 0,
             cr: (.cache_read_tokens // 0), think: 0, web: 0, side: false, model: $agy_model}) ) as $agy
    | ($cc + $agy) as $m
    | ( [ .[] | select(.type == "assistant") | (.message.content // [])[]? | select(type == "object" and .type == "tool_use") ]
        | unique_by(.id // tostring) ) as $tu
    | ( [ .[] | select(.type == "PLANNER_RESPONSE") | (.tool_calls // [])[]? | {name: (.name // "")} ] ) as $agy_tu
    | ( [ .[] | select(.type == "user") | .message.content | if type == "string" then . else ([.[]? | .text? // empty] | join(" ")) end
          | [scan("<command-name>/?([^<]+)</command-name>") | .[0]] | .[] ] ) as $slash
    | ( [ .[] | (.timestamp // .created_at // empty) | strings | ms | numbers ] ) as $times
    | {
        input:  ($m | map(.in) | add // 0),
        output: ($m | map(.out) | add // 0),
        cache_creation: ($m | map(.cw) | add // 0),
        cache_read: ($m | map(.cr) | add // 0),
        thinking: ($m | map(.think) | add // 0),
        web_searches: ($m | map(.web) | add // 0),
        api_calls: ($m | length),
        context: (($m | map(select(.side | not)) | last // {in:0,cw:0,cr:0}) | .in + .cw + .cr),
        peak_context: ($m | map(select(.side | not) | .in + .cw + .cr) | max // 0),
        model: ($m | map(.model | select(. != "")) | last // ""),
        tool_calls: (($tu + $agy_tu) | map(.name // "") | map(select(. != "")) | group_by(.) | map({key: .[0], value: length}) | from_entries),
        skills: ($tu | map(select(.name == "Skill") | .input.skill // empty) | unique),
        slash_commands: ($slash | unique),
        compactions: ([ .[] | select(.type == "system" and .subtype == "compact_boundary") ] | length),
        first_ts_ms: ($times | min // 0),
        last_ts_ms: ($times | max // 0)
      }' 2>/dev/null)

  if [ -n "$USAGE_JSON" ]; then
    INPUT_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.input // 0' 2>/dev/null)
    OUTPUT_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.output // 0' 2>/dev/null)
    CACHE_CREATE_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.cache_creation // 0' 2>/dev/null)
    CACHE_READ_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.cache_read // 0' 2>/dev/null)
    MODEL=$(printf '%s' "$USAGE_JSON" | jq -r '.model // empty' 2>/dev/null)
    EXTRA_JSON=$(printf '%s' "$USAGE_JSON" | jq -c '{thinking_tokens: .thinking, web_searches, api_calls,
      context_tokens: .context, peak_context_tokens: .peak_context, tool_calls, skills, slash_commands, compactions}
      | with_entries(select(.value != 0 and .value != [] and .value != {}))' 2>/dev/null) || EXTRA_JSON='{}'
    [ -n "$EXTRA_JSON" ] || EXTRA_JSON='{}'
    FIRST_TS_MS=$(printf '%s' "$USAGE_JSON" | jq -r '.first_ts_ms // 0' 2>/dev/null) || FIRST_TS_MS=0
    [[ "$FIRST_TS_MS" =~ ^[0-9]+$ ]] || FIRST_TS_MS=0
    # No prompt mark and no tool-call mark (e.g. Antigravity outside a devflow
    # project): time the turn from its first transcript entry (≤ 6h sanity cap)
    if [ "$PROMPT_MS" -eq 0 ] && [ "${STARTED_EPOCH:-0}" -eq 0 ] && [ "$FIRST_TS_MS" -gt 0 ] \
       && [ "$NOW_MS" -ge "$FIRST_TS_MS" ] && [ $(( NOW_MS - FIRST_TS_MS )) -le 21600000 ]; then
      DURATION_MS=$(( NOW_MS - FIRST_TS_MS ))
      DURATION_SEC=$(( (DURATION_MS + 500) / 1000 ))
    fi
    # Command typed as /devflow.<step> but not yet attributed → use it
    if [ -z "$COMMAND" ]; then
      COMMAND=$(printf '%s' "$USAGE_JSON" | jq -r '[.slash_commands[] | select(test("devflow"))] | first // empty' 2>/dev/null \
        | sed -E 's/^.*devflow[-.]//') || COMMAND=""
    fi

    TOTAL_TOK=$(( ${INPUT_TOK:-0} + ${OUTPUT_TOK:-0} + ${CACHE_CREATE_TOK:-0} + ${CACHE_READ_TOK:-0} ))
    if [ "$TOTAL_TOK" -gt 0 ]; then
      HAS_TRANSCRIPT_USAGE=1
      COST=$(df_estimate_cost "$MODEL" "$INPUT_TOK" "$OUTPUT_TOK" "$CACHE_CREATE_TOK" "$CACHE_READ_TOK")

      ENTRY=$(jq -cn \
        --arg ts "$ENDED_AT" --arg session "$SESSION" --arg step "$STEP" \
        --arg command "$COMMAND" --arg feature "$FEATURE" --arg active_feature "$ACTIVE_FEATURE" \
        --arg started_at "$STARTED_AT" --arg ended_at "$ENDED_AT" --argjson duration_sec "$DURATION_SEC" \
        --arg model "$MODEL" --argjson input "$INPUT_TOK" --argjson output "$OUTPUT_TOK" \
        --argjson cache_creation "$CACHE_CREATE_TOK" --argjson cache_read "$CACHE_READ_TOK" \
        --argjson cost "$COST" --argjson duration_ms "$DURATION_MS" --argjson extra "$EXTRA_JSON" \
        --arg host "$DF_HOST" --arg plugin_version "$PLUGIN_VERSION" \
        '{ts:$ts, session:(if $session!="" then $session else null end),
          host:(if $host!="" then $host else null end),
          plugin_version:(if $plugin_version!="" then $plugin_version else null end),
          step:(if $step!="" then $step else null end),
          command:(if $command!="" then $command else null end),
          feature:(if $feature!="" then $feature else null end),
          active_feature:(if $active_feature!="" then $active_feature else null end),
          started_at:(if $started_at!="" then $started_at else null end),
          ended_at:(if $ended_at!="" then $ended_at else null end),
          duration_sec:$duration_sec, duration_ms:$duration_ms,
          model:(if $model!="" then $model else null end),
          input_tokens:$input, output_tokens:$output,
          cache_creation_tokens:$cache_creation, cache_read_tokens:$cache_read,
          estimated_cost_usd:$cost}
         + $extra
         | with_entries(select(.value != null))' 2>/dev/null) || true
      df_rotate "$LOG_FILE" 2097152
      [ -n "$ENTRY" ] && df_append "$LOG_FILE" "$ENTRY"
    fi
  fi
fi

# Record command timing entry in timings.jsonl when active feature or command is present
# (or when transcript usage was recorded)
if [ "$TIMINGS_FILE" != "off" ] && [ "$LOG_FILE" != "off" ]; then
  if [ "$HAS_TRANSCRIPT_USAGE" -eq 1 ] || [ -n "$ACTIVE_FEATURE" ] || [ -n "$COMMAND" ]; then
    ENTRY=$(jq -cn \
      --arg ts "$ENDED_AT" \
      --arg session "$SESSION" \
      --arg command "${COMMAND:-unknown}" \
      --arg step "$STEP" \
      --arg feature "$FEATURE" \
      --arg active_feature "$ACTIVE_FEATURE" \
      --arg started_at "$STARTED_AT" \
      --arg ended_at "$ENDED_AT" \
      --argjson duration_sec "$DURATION_SEC" \
      --arg model "$MODEL" \
      --argjson input "${INPUT_TOK:-0}" \
      --argjson output "${OUTPUT_TOK:-0}" \
      --argjson cost "${COST:-null}" \
      '{
        ts: $ts,
        session: (if $session != "" then $session else null end),
        command: $command,
        step: (if $step != "" then $step else null end),
        feature: (if $feature != "" then $feature else null end),
        active_feature: (if $active_feature != "" then $active_feature else null end),
        started_at: $started_at,
        ended_at: $ended_at,
        duration_sec: $duration_sec,
        model: (if $model != "" then $model else null end),
        input_tokens: $input,
        output_tokens: $output,
        estimated_cost_usd: $cost
      } | with_entries(select(.value != null))' 2>/dev/null) || true
    df_rotate "$TIMINGS_FILE" 2097152
    [ -n "$ENTRY" ] && df_append "$TIMINGS_FILE" "$ENTRY"
  fi
fi

# Reset turn timing markers for the next turn
# (last_command survives so pre-model-switch.sh knows which step ran last)
[ -f "$OBS_STATE" ] && df_json_update "$OBS_STATE" \
  '(if (.active_command // "") != "" then .last_command = .active_command else . end)
   | del(.turn_started_at, .turn_started_epoch, .active_command, .prompt_started_ms)'

# Auto-sync DevFlow Board if already initialized in workspace
if [ -f "$WORKSPACE_ROOT/devflow/board/index.html" ]; then
  BOARD_SH="$SCRIPT_DIR/../scripts/board.sh"
  [ ! -f "$BOARD_SH" ] && BOARD_SH="$WORKSPACE_ROOT/templates/devflow/scripts/board.sh"
  if [ -f "$BOARD_SH" ]; then
    (cd "$WORKSPACE_ROOT" && bash "$BOARD_SH" --sync --quiet >/dev/null 2>&1) || true
  fi
fi

exit 0
