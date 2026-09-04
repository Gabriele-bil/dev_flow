#!/bin/bash
# stop-metrics.sh — Stop hook: per-turn token/cost estimate, appended to
# .devflow-metrics.jsonl (gitignored). Async — no passthrough required.
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

TRANSCRIPT=$(printf '%s' "$RAW" | jq -r '.transcript_path // empty' 2>/dev/null) || true
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

LOG_FILE="${DEVFLOW_METRICS_LOG:-.devflow-metrics.jsonl}"
[ "$LOG_FILE" = "off" ] && exit 0

SESSION=$(printf '%s' "$RAW" | jq -r '.session_id // empty' 2>/dev/null) || true

STATE_FILE=".devflow-state.json"
STEP=""
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

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
[ -z "$USAGE_JSON" ] && exit 0

INPUT_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.input' 2>/dev/null)
OUTPUT_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.output' 2>/dev/null)
CACHE_CREATE_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.cache_creation' 2>/dev/null)
CACHE_READ_TOK=$(printf '%s' "$USAGE_JSON" | jq -r '.cache_read' 2>/dev/null)
MODEL=$(printf '%s' "$USAGE_JSON" | jq -r '.model' 2>/dev/null)

TOTAL_TOK=$(( ${INPUT_TOK:-0} + ${OUTPUT_TOK:-0} + ${CACHE_CREATE_TOK:-0} + ${CACHE_READ_TOK:-0} ))
[ "$TOTAL_TOK" -eq 0 ] && exit 0

# Built-in $/MTok table (approximate; override via DEVFLOW_PRICING_JSON).
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

COST=null
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

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

jq -cn \
  --arg ts "$TS" --arg session "$SESSION" --arg step "$STEP" --arg feature "$FEATURE" \
  --arg model "$MODEL" --argjson input "$INPUT_TOK" --argjson output "$OUTPUT_TOK" \
  --argjson cache_creation "$CACHE_CREATE_TOK" --argjson cache_read "$CACHE_READ_TOK" \
  --argjson cost "$COST" \
  '{ts:$ts, session:(if $session!="" then $session else null end),
    step:(if $step!="" then $step else null end),
    feature:(if $feature!="" then $feature else null end),
    model:(if $model!="" then $model else null end),
    input_tokens:$input, output_tokens:$output,
    cache_creation_tokens:$cache_creation, cache_read_tokens:$cache_read,
    estimated_cost_usd:$cost}
   | with_entries(select(.value != null))' \
  >> "$LOG_FILE" 2>/dev/null || true

if [ -f .gitignore ] && ! grep -qF ".devflow-metrics.jsonl" .gitignore 2>/dev/null; then
  printf '\n# devflow token/cost metrics (estimate)\n.devflow-metrics.jsonl\n' >> .gitignore 2>/dev/null || true
fi

exit 0
