#!/bin/bash
# PostToolUse hook: accumulates modified file paths into .devflow-changed-files.tmp
# Triggered after Write, Edit, MultiEdit tool calls.

RAW=$(cat)  # consume stdin (not a passthrough hook)

# Require jq
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Extract tool name
TOOL_NAME=$(printf '%s' "$RAW" | jq -r '.tool_use.name // empty' 2>/dev/null)

# Only act on Write, Edit, or MultiEdit
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
  exit 0
fi

# Extract file_path
FILE_PATH=$(printf '%s' "$RAW" | jq -r '.tool_use.input.file_path // empty' 2>/dev/null)

# Skip if empty
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Append only if not already present
TMP_FILE=".devflow-changed-files.tmp"

if [[ -f "$TMP_FILE" ]] && grep -qF "$FILE_PATH" "$TMP_FILE" 2>/dev/null; then
  exit 0
fi

printf '%s\n' "$FILE_PATH" >> "$TMP_FILE"

exit 0
