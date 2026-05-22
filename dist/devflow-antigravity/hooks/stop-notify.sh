#!/bin/bash
# stop-notify.sh — Stop hook: macOS desktop notification when Claude finishes a response.
# Receives JSON stop event on stdin, outputs nothing meaningful to stdout.

# Consume stdin to avoid broken pipe issues
cat > /dev/null

# Only run on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi

# Try to read context from .devflow-state.json in CWD
STATE_FILE=".devflow-state.json"
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
