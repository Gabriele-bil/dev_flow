#!/bin/bash
# post-model-switch.sh — PostModelSwitch hook: audit log of model switches.
# Async, non-blocking — records what pre-model-switch.sh only decides on.
# Appends one JSONL line per switch to .devflow-model-switch.jsonl (gitignored).
# Read by devflow.status / devflow.learn for after-the-fact review of model
# changes mid-pipeline; not required for any gating decision.

command -v jq >/dev/null 2>&1 || exit 0

RAW=$(cat) || true
[ -z "$RAW" ] && exit 0

TO_MODEL=$(printf '%s' "$RAW" | jq -r '.to_model // .target_model // .new_model // empty' 2>/dev/null) || true
FROM_MODEL=$(printf '%s' "$RAW" | jq -r '.from_model // .current_model // empty' 2>/dev/null) || true
[ -z "$TO_MODEL" ] && [ -z "$FROM_MODEL" ] && exit 0

SESSION=$(printf '%s' "$RAW" | jq -r '.session_id // empty' 2>/dev/null) || true

STATE_FILE=".devflow-state.json"
STEP=""
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

LOG_FILE="${DEVFLOW_MODEL_SWITCH_LOG:-.devflow-model-switch.jsonl}"
[ "$LOG_FILE" = "off" ] && exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

jq -cn \
  --arg ts "$TS" --arg from "$FROM_MODEL" --arg to "$TO_MODEL" \
  --arg session "$SESSION" --arg step "$STEP" --arg feature "$FEATURE" \
  '{ts:$ts, from:$from, to:$to, session:(if $session!="" then $session else null end),
    step:(if $step!="" then $step else null end), feature:(if $feature!="" then $feature else null end)}
   | with_entries(select(.value != null))' \
  >> "$LOG_FILE" 2>/dev/null || true

if [ -f .gitignore ] && ! grep -qF ".devflow-model-switch.jsonl" .gitignore 2>/dev/null; then
  printf '\n# devflow model-switch audit log\n.devflow-model-switch.jsonl\n' >> .gitignore 2>/dev/null || true
fi

exit 0
