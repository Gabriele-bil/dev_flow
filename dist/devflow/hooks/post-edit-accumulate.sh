#!/bin/bash
# PostToolUse hook: accumulates modified file paths into .devflow-changed-files.tmp
# Triggered after file write/edit tools (both hosts; see lib/payload.sh DF_TOOL).
# Also triggers board.sh --sync --quiet when a DevFlow artifact or state file
# is modified and devflow/board/index.html exists.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
SCRIPT_DIR="$HOOK_DIR"

df_read_input || exit 0
df_is_edit || exit 0

FILE_PATH="$DF_FILE"
[[ -z "$FILE_PATH" ]] && exit 0

WORKSPACE_ROOT="$DF_WORKSPACE"
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
