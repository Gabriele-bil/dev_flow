#!/bin/bash
# stop-metrics.sh — Stop hook: per-turn token/cost estimate + command timing,
# appended to .devflow-metrics.jsonl and .devflow-timings.jsonl (gitignored).
# Also triggers board.sh --sync --quiet when devflow/board/index.html exists.
# Async — no passthrough required.
#
# Reads transcript_path from the Stop event, sums usage across assistant
# messages in the tail of that JSONL transcript (deduped by message id where
# present), and estimates cost from a small built-in $/MTok table. Pricing
# drifts — this is a local, approximate signal for relative cost tracking
# across features/steps, not a billing source of truth. Override the table
# with DEVFLOW_PRICING_JSON='{"claude-opus-5":{"in":15,"out":75}, ...}'
# (values are USD per million tokens, {in, out} only — cache tokens priced
# at the "in" rate as an approximation).
#
# Bounded work: only the last DEVFLOW_METRICS_TAIL_BYTES of the transcript
# are parsed, so a long-running session never pays full-file cost each stop.

command -v jq >/dev/null 2>&1 || exit 0

RAW=$(cat) || true
[ -z "$RAW" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG_FILE="${DEVFLOW_METRICS_LOG:-$WORKSPACE_ROOT/.devflow-metrics.jsonl}"
TIMINGS_FILE="${DEVFLOW_TIMINGS_LOG:-$WORKSPACE_ROOT/.devflow-timings.jsonl}"

SESSION=$(printf '%s' "$RAW" | jq -r '.session_id // empty' 2>/dev/null) || true

STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
STEP=""
FEATURE=""
ACTIVE_FEATURE=""
ACTIVE_CMD=""
STARTED_AT=""
STARTED_EPOCH=0
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  ACTIVE_FEATURE=$(jq -r '.active_feature // .feature // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE="$ACTIVE_FEATURE"
  ACTIVE_CMD=$(jq -r '.active_command // empty' "$STATE_FILE" 2>/dev/null) || true
  STARTED_AT=$(jq -r '.turn_started_at // .saved_at // empty' "$STATE_FILE" 2>/dev/null) || true
  STARTED_EPOCH=$(jq -r '.turn_started_epoch // 0' "$STATE_FILE" 2>/dev/null) || STARTED_EPOCH=0
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

TRANSCRIPT=$(printf '%s' "$RAW" | jq -r '.transcript_path // empty' 2>/dev/null) || true

INPUT_TOK=0
OUTPUT_TOK=0
CACHE_CREATE_TOK=0
CACHE_READ_TOK=0
MODEL=""
COST=null
HAS_TRANSCRIPT_USAGE=0

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && [ "$LOG_FILE" != "off" ]; then
  TAIL_BYTES="${DEVFLOW_METRICS_TAIL_BYTES:-2000000}"

  # Sum usage across assistant messages in the transcript tail, deduped by
  # message id (Claude Code transcripts may repeat cumulative usage per id).
  USAGE_JSON=$(tail -c "$TAIL_BYTES" "$TRANSCRIPT" 2>/dev/null | jq -s '
    [ .[] | select(.type == "assistant" and .message.usage != null) ] as $msgs
    | ($msgs | unique_by(.message.id // (.message.usage | tostring)))
    | {
        input:  (map(.message.usage.input_tokens // 0) | add // 0),
        output: (map(.message.usage.output_tokens // 0) | add // 0),
        cache_creation: (map(.message.usage.cache_creation_input_tokens // 0) | add // 0),
        cache_read: (map(.message.usage.cache_read_input_tokens // 0) | add // 0),
        model: (map(.message.model // empty) | last // "")
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
      DEFAULT_PRICING='{
        "opus":   {"in": 15,  "out": 75},
        "sonnet": {"in": 3,   "out": 15},
        "haiku":  {"in": 0.8, "out": 4}
      }'
      PRICING="${DEVFLOW_PRICING_JSON:-$DEFAULT_PRICING}"

      RATE_KEY="unknown"
      case "$MODEL" in
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
             else ((($in_tok + $cache_c + $cache_r) * $rate.in + $out_tok * $rate.out) / 1000000)
             end' 2>/dev/null)
        [ -z "$COST" ] && COST=null
      fi

      jq -cn \
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
         | with_entries(select(.value != null))' \
        >> "$LOG_FILE" 2>/dev/null || true

      if [ -f "$WORKSPACE_ROOT/.gitignore" ] && ! grep -qF ".devflow-metrics.jsonl" "$WORKSPACE_ROOT/.gitignore" 2>/dev/null; then
        printf '\n# devflow token/cost metrics (estimate)\n.devflow-metrics.jsonl\n' >> "$WORKSPACE_ROOT/.gitignore" 2>/dev/null || true
      fi
    fi
  fi
fi

# Record command timing entry in .devflow-timings.jsonl when active feature or command is present
# (or when transcript usage was recorded)
if [ "$TIMINGS_FILE" != "off" ] && [ "$LOG_FILE" != "off" ]; then
  if [ "$HAS_TRANSCRIPT_USAGE" -eq 1 ] || [ -n "$ACTIVE_FEATURE" ] || [ -n "$COMMAND" ]; then
    jq -cn \
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
      } | with_entries(select(.value != null))' \
      >> "$TIMINGS_FILE" 2>/dev/null || true

    if [ -f "$WORKSPACE_ROOT/.gitignore" ] && ! grep -qF ".devflow-timings.jsonl" "$WORKSPACE_ROOT/.gitignore" 2>/dev/null; then
      printf '\n# devflow command timing telemetry\n.devflow-timings.jsonl\n' >> "$WORKSPACE_ROOT/.gitignore" 2>/dev/null || true
    fi
  fi
fi

# Reset turn timing markers in .devflow-state.json for the next turn
if [ -f "$STATE_FILE" ]; then
  STATE_TMP="${STATE_FILE}.stop.tmp"
  jq 'del(.turn_started_at, .turn_started_epoch, .active_command)' "$STATE_FILE" > "$STATE_TMP" 2>/dev/null \
    && mv "$STATE_TMP" "$STATE_FILE" 2>/dev/null || rm -f "$STATE_TMP" 2>/dev/null || true
fi

# Auto-sync DevFlow Board if already initialized in workspace
if [ -f "$WORKSPACE_ROOT/devflow/board/index.html" ]; then
  BOARD_SH="$SCRIPT_DIR/../scripts/board.sh"
  [ ! -f "$BOARD_SH" ] && BOARD_SH="$WORKSPACE_ROOT/templates/devflow/scripts/board.sh"
  if [ -f "$BOARD_SH" ]; then
    (cd "$WORKSPACE_ROOT" && bash "$BOARD_SH" --sync --quiet >/dev/null 2>&1) || true
  fi
fi

exit 0
