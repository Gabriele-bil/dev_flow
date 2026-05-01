#!/bin/bash
# dev-flow session start hook
# Injects devflow-discovery meta-skill into every new session

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")/skills"
META_SKILL="$SKILLS_DIR/devflow-discovery/SKILL.md"

if ! command -v jq >/dev/null 2>&1; then
  echo '{"priority": "INFO", "message": "dev-flow: jq required for session-start hook but not found. Install jq (brew install jq) to enable pipeline orientation. Skills remain available individually."}'
  exit 0
fi

if [ -f "$META_SKILL" ]; then
  CONTENT=$(cat "$META_SKILL")
  jq -cn \
    --arg message "dev-flow loaded. Use the decision tree below to find correct pipeline entry point.

$CONTENT" \
    '{priority: "IMPORTANT", message: $message}'
else
  echo '{"priority": "INFO", "message": "dev-flow: devflow-discovery skill not found. Run devflow.setup if this is a new project."}'
fi
