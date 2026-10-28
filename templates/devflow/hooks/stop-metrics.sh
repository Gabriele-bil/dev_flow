#!/bin/bash
# stop-metrics.sh — Stop hook: per-turn token/cost estimate + command timing,
# appended to .devflow-metrics.jsonl and .devflow-timings.jsonl (gitignored).
# Also triggers board.sh --sync --quiet when devflow/board/index.html exists.
# Async, no stdout.
#
# Per-turn usage: only the transcript bytes appended since the previous Stop
# are parsed (offset kept in .devflow-observe-state.json), so each row is this
# turn's usage — summing rows never double-counts. Deduped by message id.
# Claude Code transcript: assistant entries with .message.usage.
# Antigravity transcript: PLANNER_RESPONSE entries with input/output/
# cache_read_tokens (model from the Stop payload; no price → cost omitted).
#
# Cost: USD per million tokens, per model family, with cache writes and cache
# reads priced separately. Local estimate for relative tracking, not billing.
# Override with DEVFLOW_PRICING_JSON='{"opus":{"in":4,"out":20,"cache_write":5,"cache_read":0.2}, ...}'

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0
RAW="$DF_RAW"

SCRIPT_DIR="$HOOK_DIR"
WORKSPACE_ROOT="$DF_WORKSPACE"
LOG_FILE="${DEVFLOW_METRICS_LOG:-$WORKSPACE_ROOT/.devflow-metrics.jsonl}"
TIMINGS_FILE="${DEVFLOW_TIMINGS_LOG:-$WORKSPACE_ROOT/.devflow-timings.jsonl}"

SESSION="$DF_SESSION"

STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$WORKSPACE_ROOT/.devflow-observe-state.json}"
STEP=""
FEATURE=""
ACTIVE_FEATURE=""
ACTIVE_CMD=""
STARTED_AT=""
STARTED_EPOCH=0
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  ACTIVE_FEATURE=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE="$ACTIVE_FEATURE"
fi
if [ -f "$OBS_STATE" ]; then
  ACTIVE_CMD=$(jq -r '.active_command // empty' "$OBS_STATE" 2>/dev/null) || true
  STARTED_AT=$(jq -r '.turn_started_at // empty' "$OBS_STATE" 2>/dev/null) || true
  STARTED_EPOCH=$(jq -r '.turn_started_epoch // 0' "$OBS_STATE" 2>/dev/null) || STARTED_EPOCH=0
fi

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
    ( [ .[] | select(.type == "assistant" and .message.usage != null) ]
      | unique_by(.message.id // (.message.usage | tostring))
      | map({in: (.message.usage.input_tokens // 0), out: (.message.usage.output_tokens // 0),
             cw: (.message.usage.cache_creation_input_tokens // 0), cr: (.message.usage.cache_read_input_tokens // 0),
             model: (.message.model // "")}) ) as $cc
    | ( [ .[] | select(.type == "PLANNER_RESPONSE" and (.input_tokens != null or .output_tokens != null)) ]
      | map({in: (.input_tokens // 0), out: (.output_tokens // 0), cw: 0,
             cr: (.cache_read_tokens // 0), model: $agy_model}) ) as $agy
    | ($cc + $agy) as $m
    | {
        input:  ($m | map(.in) | add // 0),
        output: ($m | map(.out) | add // 0),
        cache_creation: ($m | map(.cw) | add // 0),
        cache_read: ($m | map(.cr) | add // 0),
        model: ($m | map(.model | select(. != "")) | last // "")
      }' 2>/dev/null)

  if [ -n "$USAGE_JSON" ]; then
    INPUT_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.input // 0' 2>/dev/null)
    OUTPUT_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.output // 0' 2>/dev/null)
    CACHE_CREATE_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.cache_creation // 0' 2>/dev/null)
    CACHE_READ_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.cache_read // 0' 2>/dev/null)
    MODEL=$(printf '%s' "$USAGE_JSON" | jq -r '.model // empty' 2>/dev/null)

    TOTAL_TOK=$(( ${INPUT_TOK:-0} + ${OUTPUT_TOK:-0} + ${CACHE_CREATE_TOK:-0} + ${CACHE_READ_TOK:-0} ))
    if [ "$TOTAL_TOK" -gt 0 ]; then
      HAS_TRANSCRIPT_USAGE=1
      # Latest generation per family (Fable 5.1, Opus 5.5, Sonnet 5.5, Haiku 5.5),
      # USD/MTok. cache_write = 1.25 × input (5-minute cache).
      DEFAULT_PRICING='{
        "fable":  {"in": 10,  "out": 50,  "cache_write": 12.5,  "cache_read": 0.25},
        "opus":   {"in": 4,   "out": 20,  "cache_write": 5,     "cache_read": 0.2},
        "sonnet": {"in": 2,   "out": 10,  "cache_write": 2.5,   "cache_read": 0.2},
        "haiku":  {"in": 0.1, "out": 0.5, "cache_write": 0.125, "cache_read": 0.01}
      }'
      PRICING="${DEVFLOW_PRICING_JSON:-$DEFAULT_PRICING}"

      RATE_KEY="unknown"
      case "$MODEL" in
        *fable*|*mythos*) RATE_KEY="fable" ;;
        *opus*)   RATE_KEY="opus" ;;
        *sonnet*) RATE_KEY="sonnet" ;;
        *haiku*)  RATE_KEY="haiku" ;;
      esac

      if [ "$RATE_KEY" != "unknown" ]; then
        COST=$(jq -n --argjson p "$PRICING" --arg k "$RATE_KEY" \
          --argjson in_tok "$INPUT_TOK" --argjson out_tok "$OUTPUT_TOK" \
          --argjson cache_c "$CACHE_CREATE_TOK" --argjson cache_r "$CACHE_READ_TOK" \
          '($p[$k] // null) as $rate
           | if $rate == null then null
             else (($in_tok * $rate.in
                    + $out_tok * $rate.out
                    + $cache_c * ($rate.cache_write // $rate.in)
                    + $cache_r * ($rate.cache_read // ($rate.in / 10))) / 1000000)
             end' 2>/dev/null)
        [ -z "$COST" ] && COST=null
      fi

      ENTRY=$(jq -cn \
        --arg ts "$ENDED_AT" --arg session "$SESSION" --arg step "$STEP" \
        --arg command "$COMMAND" --arg feature "$FEATURE" --arg active_feature "$ACTIVE_FEATURE" \
        --arg started_at "$STARTED_AT" --arg ended_at "$ENDED_AT" --argjson duration_sec "$DURATION_SEC" \
        --arg model "$MODEL" --argjson input "$INPUT_TOK" --argjson output "$OUTPUT_TOK" \
        --argjson cache_creation "$CACHE_CREATE_TOK" --argjson cache_read "$CACHE_READ_TOK" \
        --argjson cost "$COST" \
        '{ts:$ts, session:(if $session!="" then $session else null end),
          step:(if $step!="" then $step else null end),
          command:(if $command!="" then $command else null end),
          feature:(if $feature!="" then $feature else null end),
          active_feature:(if $active_feature!="" then $active_feature else null end),
          started_at:(if $started_at!="" then $started_at else null end),
          ended_at:(if $ended_at!="" then $ended_at else null end),
          duration_sec:$duration_sec,
          model:(if $model!="" then $model else null end),
          input_tokens:$input, output_tokens:$output,
          cache_creation_tokens:$cache_creation, cache_read_tokens:$cache_read,
          estimated_cost_usd:$cost}
         | with_entries(select(.value != null))' 2>/dev/null) || true
      df_rotate "$LOG_FILE" 2097152
      [ -n "$ENTRY" ] && df_append "$LOG_FILE" "$ENTRY"
      df_gitignore ".devflow-metrics.jsonl" ".devflow-metrics.jsonl.1"
    fi
  fi
fi

# Record command timing entry in .devflow-timings.jsonl when active feature or command is present
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
    df_gitignore ".devflow-timings.jsonl" ".devflow-timings.jsonl.1"
  fi
fi

# Reset turn timing markers for the next turn
# (last_command survives so pre-model-switch.sh knows which step ran last)
[ -f "$OBS_STATE" ] && df_json_update "$OBS_STATE" \
  '(if (.active_command // "") != "" then .last_command = .active_command else . end)
   | del(.turn_started_at, .turn_started_epoch, .active_command)'

# Auto-sync DevFlow Board if already initialized in workspace
if [ -f "$WORKSPACE_ROOT/devflow/board/index.html" ]; then
  BOARD_SH="$SCRIPT_DIR/../scripts/board.sh"
  [ ! -f "$BOARD_SH" ] && BOARD_SH="$WORKSPACE_ROOT/templates/devflow/scripts/board.sh"
  if [ -f "$BOARD_SH" ]; then
    (cd "$WORKSPACE_ROOT" && bash "$BOARD_SH" --sync --quiet >/dev/null 2>&1) || true
  fi
fi

exit 0
