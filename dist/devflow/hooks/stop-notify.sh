#!/bin/bash
# stop-notify.sh — Stop hook: macOS desktop notification when Claude finishes a response.
# Receives JSON stop event on stdin, outputs nothing meaningful to stdout.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"

# Consume stdin and resolve the workspace (works without jq too)
df_read_input || cat >/dev/null 2>&1

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi

WORKSPACE_ROOT="${DF_WORKSPACE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
TITLE="DevFlow"
BODY="Claude is done"

if [ -f "$STATE_FILE" ]; then
  # Use jq if available, otherwise fall back to basic grep/sed
  if command -v jq > /dev/null 2>&1; then
    FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || true
    NEXT_STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || true
  else
    FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | sed 's/.*: *"//' | sed 's/"$//' | head -1) || true
    NEXT_STEP=$(grep -o '"next_step"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" 2>/dev/null | sed 's/.*: *"//' | sed 's/"$//' | head -1) || true
  fi

  if [ -n "$FEATURE" ]; then
    TITLE="DevFlow: $FEATURE"
  fi

  if [ -n "$NEXT_STEP" ]; then
    # Strip leading "devflow." prefix if present
    STEP_LABEL="${NEXT_STEP#devflow.}"
    BODY="Ready for devflow.$STEP_LABEL"
  fi
fi

# Send macOS notification (run in background to be non-blocking)
(osascript -e "display notification \"$BODY\" with title \"$TITLE\"" > /dev/null 2>&1) &

exit 0
