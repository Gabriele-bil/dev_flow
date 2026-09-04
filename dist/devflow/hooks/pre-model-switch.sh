#!/bin/bash
# pre-model-switch.sh — PreModelSwitch hook: block a switch away from a
# security-grade model while a DevFlow step that requires one is active.
# Enforces the anti-pattern already documented in references/model-selection.md
# ("Haiku for devflow.ship agents — security misses on cost optimization =
# false confidence"): a prose rule an agent could rationalize past. Hooks
# can't be rationalized around — see CONTRIBUTING.md "Choosing a Mechanism".
#
# Reads model-switch fields defensively (field names not yet stabilized
# upstream): tries to_model/target_model/new_model and from_model/current_model.
# Fail-open on any ambiguity — this hook only blocks on a high-confidence match
# (known cheap-model name + known security-sensitive step); everything else
# passes through unblocked.
#
# Stdin: PreModelSwitch event JSON. Stdout (only on block): control JSON
# {"decision":"block","reason":"..."}. Silent exit 0 = allow.

command -v jq >/dev/null 2>&1 || exit 0

RAW=$(cat) || true
[ -z "$RAW" ] && exit 0

TO_MODEL=$(printf '%s' "$RAW" | jq -r '.to_model // .target_model // .new_model // empty' 2>/dev/null) || true
[ -z "$TO_MODEL" ] && exit 0

STATE_FILE=".devflow-state.json"
STEP=""
[ -f "$STATE_FILE" ] && STEP=$(jq -r '.next_step // .last_observed_step // empty' "$STATE_FILE" 2>/dev/null) || true
[ -z "$STEP" ] && exit 0

# Security-sensitive steps per model-selection.md Decision Table (Opus/Sonnet
# reserved — ship dispatches security-auditor, test dispatches coverage review).
case "$STEP" in
  devflow.ship|devflow-ship) ;;
  *) exit 0 ;;
esac

# Cheap-model name match — conservative, known Haiku identifiers only.
case "$TO_MODEL" in
  *haiku*|*Haiku*) ;;
  *) exit 0 ;;
esac

jq -cn --arg reason \
  "devflow: blocked switch to $TO_MODEL during $STEP — security/correctness review agents need Sonnet/Opus (references/model-selection.md anti-pattern: 'Haiku for devflow.ship agents = false confidence'). Finish this ship gate on the current model, or switch after devflow.ship completes." \
  '{decision:"block", reason:$reason}'
exit 0
