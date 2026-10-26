#!/bin/bash
# PostToolUse hook: accumulates modified file paths into .devflow-changed-files.tmp
# Triggered after Write, Edit, MultiEdit tool calls.
# Also triggers board.sh --sync --quiet when a DevFlow artifact or state file
# is modified and devflow/board/index.html exists.

RAW=$(cat) || true  # consume stdin (not a passthrough hook)
[ -z "$RAW" ] && exit 0

# Require jq
if ! command -v jq &>/dev/null; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TMP_FILE="${DEVFLOW_CHANGED_FILES_TMP:-$WORKSPACE_ROOT/.devflow-changed-files.tmp}"

if [[ ! -f "$TMP_FILE" ]] || ! grep -qF "$FILE_PATH" "$TMP_FILE" 2>/dev/null; then
  printf '%s\n' "$FILE_PATH" >> "$TMP_FILE"
fi

# Auto-sync DevFlow Board if a feature doc, blueprint, ADR, or state file changed
if [ -f "$WORKSPACE_ROOT/devflow/board/index.html" ]; then
  if echo "$FILE_PATH" | grep -qE '(devflow/features/|devflow/plans/|docs/adr/|\.devflow-state\.json|\.devflow-timings\.jsonl|\.devflow-metrics\.jsonl)'; then
    BOARD_SH="$SCRIPT_DIR/../scripts/board.sh"
    [ ! -f "$BOARD_SH" ] && BOARD_SH="$WORKSPACE_ROOT/templates/devflow/scripts/board.sh"
    if [ -f "$BOARD_SH" ]; then
      (cd "$WORKSPACE_ROOT" && bash "$BOARD_SH" --sync --quiet >/dev/null 2>&1) || true
    fi
  fi
fi

exit 0
