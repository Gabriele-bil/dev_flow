#!/bin/bash
# dev-flow session start hook
# Injects pipeline orientation into every new session.
# Active project with known next_step in state → compact pointer (~150 tokens).
# Active project without usable state → full orientation decision tree.
# Inactive project → one-line pointer.
# Output: lib/emit.sh df_context (SessionStart additionalContext on Claude Code).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
META_SKILL="${DEVFLOW_META_SKILL:-$PLUGIN_ROOT/references/orientation.md}"
[ -f "$META_SKILL" ] || META_SKILL="$PLUGIN_ROOT/skills/devflow-discovery/SKILL.md"

. "$SCRIPT_DIR/lib/payload.sh"
. "$SCRIPT_DIR/lib/emit.sh"

if ! df_read_input; then
  # No jq: plain stdout is still added as context on SessionStart (Claude Code)
  echo "dev-flow: jq required for session-start hook but not found. Install jq (brew install jq) to enable pipeline orientation. Skills remain available individually."
  exit 0
fi
DF_EVENT="${DF_EVENT:-SessionStart}"

WORKSPACE_ROOT="$DF_WORKSPACE"
# Project config lives in the consumer repo (written by devflow.setup), never in
# the plugin dir — the plugin's config.md is an unconfigured template.
CONFIG_FILE="${DEVFLOW_CONFIG_FILE:-$WORKSPACE_ROOT/devflow/config.md}"
STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"

# Only a consumer project actively using devflow gets orientation injected
# (IMPORTANT priority). Signal: a devflow/ dir, a state file, or a config.md
# already configured (no [TODO placeholders). Otherwise this is just a
# project with the plugin installed but not yet in use — a short INFO
# pointer avoids paying for orientation content every session for nothing.
PROJECT_ACTIVE=false
if [ -d "$WORKSPACE_ROOT/devflow" ] || [ -f "$STATE_FILE" ]; then
  PROJECT_ACTIVE=true
elif [ -f "$CONFIG_FILE" ] && ! grep -q "\[TODO" "$CONFIG_FILE"; then
  PROJECT_ACTIVE=true
fi

if [ "$PROJECT_ACTIVE" != true ]; then
  df_context "dev-flow available but not set up in this project. Run /devflow.setup to start a spec-driven pipeline."
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
  FEATURE=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null) || FEATURE=""
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
  devflow.discover|devflow.setup|devflow.task|devflow.blueprint|devflow.clarify|devflow.plan| \
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
User orchestrates; only ship/run/auto/hotfix chain other steps. Full orientation: @devflow/references/orientation.md.$CONFIG_WARN"
  df_context "$MSG"
  exit 0
fi

# ── Full branch: no state, or next_step empty/unknown/unparsable ─────────────
if [ -f "$META_SKILL" ]; then
  CONTENT=$(cat "$META_SKILL")

  BASE_MSG="dev-flow loaded. Use the decision tree below to find correct pipeline entry point.

$CONTENT"

  df_context "${BASE_MSG}${CONFIG_WARN}"
else
  df_context "dev-flow: orientation reference not found. Run devflow.setup if this is a new project."
fi
