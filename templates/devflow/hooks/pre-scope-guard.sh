#!/usr/bin/env bash
# pre-scope-guard.sh
# PreToolUse soft-warning hook: checks whether a file being written/edited during
# devflow.implement is listed in the active plan.md File List / Traceability.
# Emits a non-blocking additionalContext reminder when touching an unlisted file
# so the agent either stays in lane or logs the deviation in plan.md.
#
# Triggered by: Write, Edit, MultiEdit
# Input (stdin): JSON { "tool_use": { "name": "...", "input": { "file_path": "..." } } }
# Output: { "hookSpecificOutput": { "hookEventName": "PreToolUse", "additionalContext": "..." } }
# Always exits 0 (soft warn only, never hard-blocks).

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

FILE_PATH="$(echo "$INPUT" | jq -r '.tool_use.input.file_path // empty' 2>/dev/null || true)"
[[ -z "$FILE_PATH" || "$FILE_PATH" == "null" ]] && exit 0

WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REL_PATH="${FILE_PATH#"$WORKSPACE_ROOT/"}"
BASENAME="$(basename "$FILE_PATH")"

# Skip DevFlow artifacts, docs, registries, and test files
case "$REL_PATH" in
  devflow/*|.devflow*|docs/*|REGISTRY.md|registry.md|AGENTS.md|CLAUDE.md|CHANGELOG.md|test/*|tests/*|e2e/*|integration_test/*|.maestro/*)
    exit 0
    ;;
esac
case "$BASENAME" in
  *.test.*|*.spec.*|*_test.*|.checkpoint.json|handoff.md|plan.md|task.md|verification.md|data-model.md)
    exit 0
    ;;
esac

# Resolve active plan.md
PLAN_FILE=""
STATE_FILE="$WORKSPACE_ROOT/.devflow-state.json"
if [[ -f "$STATE_FILE" ]]; then
  FEATURE_PATH="$(jq -r '.feature_path // empty' "$STATE_FILE" 2>/dev/null || true)"
  if [[ -n "$FEATURE_PATH" && -f "$WORKSPACE_ROOT/$FEATURE_PATH/plan.md" ]]; then
    PLAN_FILE="$WORKSPACE_ROOT/$FEATURE_PATH/plan.md"
  fi
fi

if [[ -z "$PLAN_FILE" && -d "$WORKSPACE_ROOT/devflow/features" ]]; then
  PLAN_FILE="$(find "$WORKSPACE_ROOT/devflow/features" -maxdepth 2 -name "plan.md" 2>/dev/null | sort | tail -n 1 || true)"
fi

[[ -z "$PLAN_FILE" || ! -f "$PLAN_FILE" ]] && exit 0

# Only enforce during active implementation (Status: implementing)
if ! grep -qE '^\*\*Status:\*\*[[:space:]]*implementing' "$PLAN_FILE" 2>/dev/null; then
  exit 0
fi

# Check if relative path or basename is referenced in plan.md
if grep -qF "$REL_PATH" "$PLAN_FILE" 2>/dev/null || grep -qF "$BASENAME" "$PLAN_FILE" 2>/dev/null; then
  exit 0
fi

WARN_MSG="⚠️ Scope Guard (soft warn): '${REL_PATH}' is not listed in active plan.md (${PLAN_FILE#"$WORKSPACE_ROOT/"}).
• If this file is Out of Scope for the current slice/lane, revert or avoid editing it.
• If this edit is required, record it in plan.md under '## Implementation deviations' (Step 7b) to preserve traceability."

jq -cn --arg ctx "$WARN_MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse", additionalContext:$ctx}}'
exit 0
