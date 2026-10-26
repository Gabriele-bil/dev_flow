#!/bin/bash
# devflow post-task-create
# Triggered after Write on any task.md under devflow/features/.
# Extracts the feature number from the path, updates next_feature_number in
# .devflow-state.json, records initial task timing telemetry, and syncs the
# DevFlow Board if devflow/board/index.html exists.

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

RAW=$(cat) || true
[ -z "$RAW" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_PATH=$(printf '%s' "$RAW" | jq -r '.tool_use.input.file_path // empty' 2>/dev/null)

# Only act on devflow/features/NNN_*/task.md writes
if ! echo "$FILE_PATH" | grep -qE 'devflow/features/[0-9]{3}_[^/]+/task\.md$'; then
  exit 0
fi

# Extract the 3-digit prefix and full feature folder name (NNN_slug)
NNN=$(echo "$FILE_PATH" | grep -oE '[0-9]{3}_' | head -1 | tr -d '_')
FEATURE_SLUG=$(echo "$FILE_PATH" | grep -oE '[0-9]{3}_[^/]+' | head -1)
if [ -z "$NNN" ]; then
  exit 0
fi

NEXT=$(printf '%03d' $((10#$NNN + 1)))
WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
TIMINGS_FILE="${DEVFLOW_TIMINGS_LOG:-$WORKSPACE_ROOT/.devflow-timings.jsonl}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
STARTED_AT="$TS"
STARTED_EPOCH=0
ENDED_EPOCH=$(date +%s 2>/dev/null || echo 0)

if [ -f "$STATE_FILE" ]; then
  STARTED_AT=$(jq -r --arg fallback "$TS" '.turn_started_at // $fallback' "$STATE_FILE" 2>/dev/null || echo "$TS")
  STARTED_EPOCH=$(jq -r '.turn_started_epoch // 0' "$STATE_FILE" 2>/dev/null || echo 0)
  # Merge next_feature_number into existing state (preserve existing feature/active_feature if present)
  UPDATED=$(jq --arg n "$NEXT" --arg f "$FEATURE_SLUG" \
    '. + {next_feature_number: $n} + (if (.active_feature // .feature // "") == "" then {active_feature: $f} else {} end)' \
    "$STATE_FILE" 2>/dev/null)
  [ -n "$UPDATED" ] && printf '%s\n' "$UPDATED" > "$STATE_FILE"
else
  # Create minimal state with counter (and active_feature)
  jq -n --arg n "$NEXT" --arg f "$FEATURE_SLUG" \
    '{next_feature_number: $n, active_feature: $f}' > "$STATE_FILE" 2>/dev/null
fi

# Record initial task command timing entry in .devflow-timings.jsonl if not already present for this feature
if [ "$TIMINGS_FILE" != "off" ] && [ -n "$FEATURE_SLUG" ]; then
  EXISTING_TASK_TIMING=""
  if [ -f "$TIMINGS_FILE" ]; then
    EXISTING_TASK_TIMING=$(jq -r --arg f "$FEATURE_SLUG" 'select((.active_feature // .feature) == $f and .command == "task") | .command' "$TIMINGS_FILE" 2>/dev/null | head -1 || true)
  fi
  if [ -z "$EXISTING_TASK_TIMING" ]; then
    DURATION_SEC=0
    if [ "${STARTED_EPOCH:-0}" -gt 0 ] && [ "${ENDED_EPOCH:-0}" -ge "${STARTED_EPOCH:-0}" ]; then
      DURATION_SEC=$(( ENDED_EPOCH - STARTED_EPOCH ))
    fi
    jq -cn \
      --arg ts "$TS" \
      --arg feat "$FEATURE_SLUG" \
      --arg started_at "$STARTED_AT" \
      --arg ended_at "$TS" \
      --argjson duration_sec "$DURATION_SEC" \
      '{
        ts: $ts,
        command: "task",
        step: "devflow.task",
        feature: $feat,
        active_feature: $feat,
        started_at: $started_at,
        ended_at: $ended_at,
        duration_sec: $duration_sec
      }' >> "$TIMINGS_FILE" 2>/dev/null || true
  fi
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
