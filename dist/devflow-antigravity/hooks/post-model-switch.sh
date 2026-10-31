#!/bin/bash
# post-model-switch.sh — PostModelSwitch hook: audit log of model switches.
# Async, non-blocking — records what pre-model-switch.sh only decides on.
# Appends one JSONL line per switch to .devflow-model-switch.jsonl (gitignored).
# Read by devflow.status / devflow.learn for after-the-fact review of model
# changes mid-pipeline; not required for any gating decision.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0

TO_MODEL=$(printf '%s' "$DF_RAW" | jq -r '.to_model // .target_model // .new_model // empty' 2>/dev/null) || true
FROM_MODEL=$(printf '%s' "$DF_RAW" | jq -r '.from_model // .current_model // empty' 2>/dev/null) || true
[ -z "$TO_MODEL" ] && [ -z "$FROM_MODEL" ] && exit 0

SESSION="$DF_SESSION"

WORKSPACE_ROOT="$DF_WORKSPACE"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
STEP=""
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  FEATURE=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || true
fi

LOG_FILE="${DEVFLOW_MODEL_SWITCH_LOG:-$WORKSPACE_ROOT/.devflow-model-switch.jsonl}"
[ "$LOG_FILE" = "off" ] && exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

ENTRY=$(jq -cn \
  --arg ts "$TS" --arg from "$FROM_MODEL" --arg to "$TO_MODEL" \
  --arg session "$SESSION" --arg step "$STEP" --arg feature "$FEATURE" \
  '{ts:$ts, from:$from, to:$to, session:(if $session!="" then $session else null end),
    step:(if $step!="" then $step else null end), feature:(if $feature!="" then $feature else null end)}
   | with_entries(select(.value != null))' 2>/dev/null) || true
df_rotate "$LOG_FILE"
[ -n "$ENTRY" ] && df_append "$LOG_FILE" "$ENTRY"
df_gitignore ".devflow-model-switch.jsonl" ".devflow-model-switch.jsonl.1"

exit 0
