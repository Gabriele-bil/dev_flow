#!/bin/bash
# dev-flow session start hook
# Injects pipeline orientation into every new session.
# Active project with known next_step in state → compact pointer (~150 tokens).
# Active project without usable state → full devflow-discovery meta-skill.
# Inactive project → one-line INFO pointer.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")/skills"
META_SKILL="${DEVFLOW_META_SKILL:-$SKILLS_DIR/devflow-discovery/SKILL.md}"

if ! command -v jq >/dev/null 2>&1; then
  echo '{"priority": "INFO", "message": "dev-flow: jq required for session-start hook but not found. Install jq (brew install jq) to enable pipeline orientation. Skills remain available individually."}'
  exit 0
fi

CONFIG_FILE="${DEVFLOW_CONFIG_FILE:-$SCRIPT_DIR/../config.md}"
STATE_FILE="$PWD/.devflow-state.json"

# Only a consumer project actively using devflow gets orientation injected
# (IMPORTANT priority). Signal: a devflow/ dir, a state file, or a config.md
# already configured (no [TODO placeholders). Otherwise this is just a
# project with the plugin installed but not yet in use — a short INFO
# pointer avoids paying for orientation content every session for nothing.
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

# Preflight: warn if config.md has not been set up yet (shared by both branches)
CONFIG_WARN=""
if [ -f "$CONFIG_FILE" ] && grep -q "\[TODO" "$CONFIG_FILE"; then
  CONFIG_WARN="

---
⚠️  devflow not configured: run /devflow.setup before any pipeline command.
Adapter is not set — config.md still has placeholder values."
fi

# Read pipeline state (consumer project cwd)
NEXT_STEP=""
FEATURE=""
if [ -f "$STATE_FILE" ]; then
  NEXT_STEP=$(jq -r '.next_step // empty' "$STATE_FILE" 2>/dev/null) || NEXT_STEP=""
  FEATURE=$(jq -r '.feature // empty' "$STATE_FILE" 2>/dev/null) || FEATURE=""
fi

# Context file hint per next step
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

# ── Compact branch: state already names the entry point ──────────────────────
# The full decision tree is redundant when next_step is a known pipeline step.
KNOWN_STEP=false
case "$NEXT_STEP" in
  devflow.setup|devflow.task|devflow.blueprint|devflow.clarify|devflow.plan| \
  devflow.analyze|devflow.implement|devflow.beautify|devflow.test|devflow.ship| \
  devflow.pr|devflow.resume|devflow.backprop|devflow.recovery|devflow.run)
    KNOWN_STEP=true
    ;;
esac

if [ "$KNOWN_STEP" = true ]; then
  FEATURE_LABEL=""
  if [ -n "$FEATURE" ]; then
    FEATURE_LABEL=" (feature: $FEATURE)"
  fi
  CTX_LINE=""
  if [ -n "$CTX" ]; then
    CTX_LINE="
Load context: $CTX"
  fi
  MSG="dev-flow active$FEATURE_LABEL. Next step: $NEXT_STEP — run /$NEXT_STEP, or /devflow.resume to re-orient after an interruption.$CTX_LINE
User is orchestrator — skills do not invoke each other. Full orientation: devflow-discovery skill.$CONFIG_WARN"
  jq -cn --arg message "$MSG" '{priority: "IMPORTANT", message: $message}'
  exit 0
fi

# ── Full branch: no state, or next_step empty/unknown/unparsable ─────────────
if [ -f "$META_SKILL" ]; then
  CONTENT=$(cat "$META_SKILL")

  BASE_MSG="dev-flow loaded. Use the decision tree below to find correct pipeline entry point.

$CONTENT"

  jq -cn \
    --arg message "${BASE_MSG}${CONFIG_WARN}" \
    '{priority: "IMPORTANT", message: $message}'
else
  echo '{"priority": "INFO", "message": "dev-flow: devflow-discovery skill not found. Run devflow.setup if this is a new project."}'
fi
