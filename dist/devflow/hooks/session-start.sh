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

CONFIG_FILE="$SCRIPT_DIR/../config.md"
STATE_FILE="$PWD/.devflow-state.json"

# Only a consumer project actively using devflow gets the full meta-skill
# injection (IMPORTANT priority). Signal: a devflow/ dir, a state file, or a
# config.md already configured (no [TODO placeholders). Otherwise this is
# just a project with the plugin installed but not yet in use — a short
# INFO pointer avoids paying for ~100 lines of meta-skill content every
# session for nothing.
PROJECT_ACTIVE=false
if [ -d "$PWD/devflow" ] || [ -f "$STATE_FILE" ]; then
  PROJECT_ACTIVE=true
elif [ -f "$CONFIG_FILE" ] && ! grep -q "\[TODO" "$CONFIG_FILE"; then
  PROJECT_ACTIVE=true
fi

if [ "$PROJECT_ACTIVE" != true ]; then
  echo '{"priority": "INFO", "message": "dev-flow available but not set up in this project. Run /devflow.setup to start a spec-driven pipeline."}'
  exit 0
fi

if [ -f "$META_SKILL" ]; then
  CONTENT=$(cat "$META_SKILL")

  # Build base message
  BASE_MSG="dev-flow loaded. Use the decision tree below to find correct pipeline entry point.

$CONTENT"

  # Preflight: warn if config.md has not been set up yet
  CONFIG_WARN=""
  if [ -f "$CONFIG_FILE" ] && grep -q "\[TODO" "$CONFIG_FILE"; then
    CONFIG_WARN="

---
⚠️  devflow not configured: run /devflow.setup before any pipeline command.
Adapter is not set — config.md still has placeholder values."
  fi

  # Check for .devflow-state.json in the current working directory (consumer project)
  CONTEXT_HINT=""
  if [ -f "$STATE_FILE" ]; then
    NEXT_STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null)
    FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null)

    case "$NEXT_STEP" in
      devflow.task|devflow.plan)
        CTX="@devflow/contexts/research.md"
        ;;
      devflow.implement|devflow.beautify)
        CTX="@devflow/contexts/implement.md"
        ;;
      devflow.ship)
        CTX="@devflow/contexts/review.md"
        ;;
      *)
        CTX=""
        ;;
    esac

    if [ -n "$CTX" ]; then
      FEATURE_LABEL=""
      if [ -n "$FEATURE" ]; then
        FEATURE_LABEL=" (feature: $FEATURE)"
      fi
      CONTEXT_HINT="

---
Active pipeline step: $NEXT_STEP$FEATURE_LABEL
Load context: $CTX"
    fi
  fi

  jq -cn \
    --arg message "${BASE_MSG}${CONFIG_WARN}${CONTEXT_HINT}" \
    '{priority: "IMPORTANT", message: $message}'
else
  echo '{"priority": "INFO", "message": "dev-flow: devflow-discovery skill not found. Run devflow.setup if this is a new project."}'
fi
