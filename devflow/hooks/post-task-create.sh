#!/bin/bash
# devflow post-task-create
# Triggered after Write on any task.md under devflow/features/.
# Extracts the feature number from the path and writes next_feature_number
# to .devflow-state.json so devflow.task can skip the directory scan.

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

RAW=$(cat)

FILE_PATH=$(printf '%s' "$RAW" | jq -r '.tool_use.input.file_path // empty' 2>/dev/null)

# Only act on devflow/features/NNN_*/task.md writes
if ! echo "$FILE_PATH" | grep -qE 'devflow/features/[0-9]{3}_[^/]+/task\.md$'; then
  exit 0
fi

# Extract the 3-digit prefix
NNN=$(echo "$FILE_PATH" | grep -oE '[0-9]{3}_' | head -1 | tr -d '_')
if [ -z "$NNN" ]; then
  exit 0
fi

NEXT=$(printf '%03d' $((10#$NNN + 1)))
STATE_FILE=".devflow-state.json"

if [ -f "$STATE_FILE" ]; then
  # Merge next_feature_number into existing state
  UPDATED=$(jq --arg n "$NEXT" '. + {next_feature_number: $n}' "$STATE_FILE" 2>/dev/null)
  [ -n "$UPDATED" ] && printf '%s\n' "$UPDATED" > "$STATE_FILE"
else
  # Create minimal state with just the counter
  jq -n --arg n "$NEXT" '{next_feature_number: $n}' > "$STATE_FILE" 2>/dev/null
fi
