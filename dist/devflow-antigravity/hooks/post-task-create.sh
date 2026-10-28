#!/bin/bash
# devflow post-task-create
# Triggered after Write on any task.md under devflow/features/.
# Extracts the feature number from the path, updates next_feature_number in
# .devflow-state.json, records initial task timing telemetry, and syncs the
# DevFlow Board if devflow/board/index.html exists.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
SCRIPT_DIR="$HOOK_DIR"

df_read_input || exit 0
FILE_PATH="$DF_FILE"

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
WORKSPACE_ROOT="$DF_WORKSPACE"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$WORKSPACE_ROOT/.devflow-observe-state.json}"
TIMINGS_FILE="${DEVFLOW_TIMINGS_LOG:-$WORKSPACE_ROOT/.devflow-timings.jsonl}"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
STARTED_AT="$TS"
STARTED_EPOCH=0
ENDED_EPOCH=$(date +%s 2>/dev/null || echo 0)

if [ -f "$OBS_STATE" ]; then
  STARTED_AT=$(jq -r --arg fallback "$TS" '.turn_started_at // $fallback' "$OBS_STATE" 2>/dev/null || echo "$TS")
  STARTED_EPOCH=$(jq -r '.turn_started_epoch // 0' "$OBS_STATE" 2>/dev/null || echo 0)
fi

# Merge counter into state (atomic, locked). Never lowers next_feature_number;
# sets the active feature only when none is recorded yet (canonical key:
# feature — active_feature is a read-only legacy alias, migrated here).
df_json_update "$STATE_FILE" '
  (if (.feature // "") == "" and (.active_feature // "") != "" then .feature = .active_feature else . end)
  | del(.active_feature)
  | ((.next_feature_number // 0) | tonumber? // 0) as $cur
  | (if $cur < $n then .next_feature_number = $n else .next_feature_number = $cur end)
  | (if (.feature // "") == "" then .feature = $f | .feature_path = ("devflow/features/" + $f) else . end)' \
  --argjson n "$((10#$NEXT))" --arg f "$FEATURE_SLUG"
df_gitignore ".devflow-state.json"

# Record initial task command timing entry in .devflow-timings.jsonl if not already present for this feature
if [ "$TIMINGS_FILE" != "off" ] && [ -n "$FEATURE_SLUG" ]; then
  EXISTING_TASK_TIMING=""
  if [ -f "$TIMINGS_FILE" ]; then
    EXISTING_TASK_TIMING=$(jq -r --arg f "$FEATURE_SLUG" 'select((.feature // .active_feature) == $f and .command == "task") | .command' "$TIMINGS_FILE" 2>/dev/null | head -1 || true)
  fi
  if [ -z "$EXISTING_TASK_TIMING" ]; then
    DURATION_SEC=0
    if [ "${STARTED_EPOCH:-0}" -gt 0 ] && [ "${ENDED_EPOCH:-0}" -ge "${STARTED_EPOCH:-0}" ]; then
      DURATION_SEC=$(( ENDED_EPOCH - STARTED_EPOCH ))
    fi
    ENTRY=$(jq -cn \
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
      }' 2>/dev/null) || true
    [ -n "$ENTRY" ] && df_append "$TIMINGS_FILE" "$ENTRY"
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
