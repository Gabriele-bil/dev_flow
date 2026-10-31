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
# Claude Code only (Antigravity CLI has no model-switch event).
# Stdin: PreModelSwitch event JSON. Stdout (only on block): control JSON
# {"decision":"block","reason":"..."}. Silent exit 0 = allow.
#
# "ship in progress" = ship is the command running this turn or the last one
# (active_command / last_command, written by observe.sh / stop-metrics.sh) and
# plan.md has not reached shipped yet. NOT next_step == devflow.ship, which
# only means ship is the next thing to run (e.g. right after devflow.test).

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"

df_read_input || exit 0
[ -z "$DF_RAW" ] && exit 0

TO_MODEL=$(printf '%s' "$DF_RAW" | jq -r '.to_model // .target_model // .new_model // empty' 2>/dev/null) || true
[ -z "$TO_MODEL" ] && exit 0

OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$DF_WORKSPACE/.devflow-observe-state.json}"
STATE_FILE="${DEVFLOW_STATE_FILE:-$DF_WORKSPACE/.devflow-state.json}"
ACTIVE=""
PLAN_STATUS=""
[ -f "$OBS_STATE" ] && ACTIVE=$(jq -r '(.active_command // "") as $a | if $a != "" then $a else (.last_command // "") end' "$OBS_STATE" 2>/dev/null) || true
[ -f "$STATE_FILE" ] && PLAN_STATUS=$(jq -r '.plan_status // empty' "$STATE_FILE" 2>/dev/null) || true

# Security-sensitive steps per model-selection.md Decision Table (Opus/Sonnet
# reserved — ship dispatches security-auditor).
[ "$ACTIVE" = "ship" ] || exit 0
case "$PLAN_STATUS" in shipped|pr-opened) exit 0 ;; esac
STEP="devflow.ship"

# Cheap-model name match — conservative, known Haiku identifiers only.
case "$TO_MODEL" in
  *haiku*|*Haiku*) ;;
  *) exit 0 ;;
esac

jq -cn --arg reason \
  "devflow: blocked switch to $TO_MODEL during $STEP — security/correctness review agents need Sonnet/Opus (references/model-selection.md anti-pattern: 'Haiku for devflow.ship agents = false confidence'). Finish this ship gate on the current model, or switch after devflow.ship completes." \
  '{decision:"block", reason:$reason}'
exit 0
