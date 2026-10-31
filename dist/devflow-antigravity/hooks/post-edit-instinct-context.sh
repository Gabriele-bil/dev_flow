#!/usr/bin/env bash
# post-edit-instinct-context.sh
# PostToolUse hook: resurface project instincts deterministically when a
# matching file is touched, instead of relying only on the SessionStart dump
# (session-start-learnings.sh) which fires once and can be forgotten by the
# time the relevant file is actually edited much later in a long session.
#
# Matches .devflow-instincts.yaml entries by domain (inferred from the edited
# file's extension) or by an exact "when editing <file>" trigger, same
# domain-inference table as session-start-learnings.sh.
#
# Triggered by: file write/edit tools (both hosts)
# Input: host payload, parsed by lib/payload.sh (DF_FILE)
# Output: lib/emit.sh df_context (additionalContext on Claude Code)
# Silent (exit 0, no stdout) when nothing matches or tooling is missing.
# Each instinct is sent once per session: lines already sent are kept in
# .devflow-observe-state.json (instincts_sent), so repeated edits of the same
# kind of file — or of plan.md while marking [done] — add no context.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

df_read_input || exit 0
command -v yq >/dev/null 2>&1 || exit 0

WORKSPACE_ROOT="$DF_WORKSPACE"
INSTINCTS_FILE="${DEVFLOW_INSTINCTS_FILE:-$WORKSPACE_ROOT/.devflow-instincts.yaml}"
MIN_CONFIDENCE="${DEVFLOW_INSTINCT_MIN_CONFIDENCE:-0.4}"
MAX_SHOW=3

[[ -f "$INSTINCTS_FILE" && -s "$INSTINCTS_FILE" ]] || exit 0

FILE_PATH="$DF_FILE"
[[ -z "$FILE_PATH" ]] && exit 0

DOMAIN="general"
case "$FILE_PATH" in *.dart)     DOMAIN="flutter"    ;; esac
case "$FILE_PATH" in *.ts|*.tsx) DOMAIN="typescript" ;; esac
case "$FILE_PATH" in *.py)       DOMAIN="python"     ;; esac
case "$FILE_PATH" in *.sh)       DOMAIN="shell"      ;; esac
case "$FILE_PATH" in *devflow*)  DOMAIN="devflow"    ;; esac

BASENAME="$(basename "$FILE_PATH")"

instinct_filter() {
  jq -r --arg domain "$DOMAIN" --arg file "$FILE_PATH" --arg base "$BASENAME" \
    --argjson min "$MIN_CONFIDENCE" --argjson max "$MAX_SHOW" '
    map(select((.confidence // 0) >= $min))
    | map(select(
        ((.domain // "general") == $domain)
        or ((.trigger // "") == ("when editing " + $file))
        or ((.trigger // "") | contains($base))))
    | sort_by(.confidence) | reverse | .[0:$max]
    | .[]
    | "• [" + (.confidence | tostring) + " " + (.domain // "general") + "] " + (.trigger // "") + " → " + (.action // "")'
}

# YAML → JSON once (yq), then filter in jq with values passed as --arg, so
# file names like "[id].tsx" or quotes can't break the expression.
ENTRIES=$(
  yq -o=json '.instincts // []' "$INSTINCTS_FILE" 2>/dev/null | instinct_filter
) || true

[[ -z "$ENTRIES" ]] && exit 0

OBS_STATE="${DEVFLOW_OBSERVE_STATE_FILE:-$WORKSPACE_ROOT/.devflow-observe-state.json}"
SENT='[]'
[[ -s "$OBS_STATE" ]] && SENT=$(jq -c --arg s "$DF_SESSION" \
  'if (.instincts_sent.session // "") == $s then (.instincts_sent.lines // []) else [] end' "$OBS_STATE" 2>/dev/null || echo '[]')
NEW=$(printf '%s\n' "$ENTRIES" | jq -R -s -c --argjson sent "${SENT:-[]}" 'split("\n") | map(select(length > 0)) - $sent')
[[ "$NEW" == "[]" || -z "$NEW" ]] && exit 0
df_json_update "$OBS_STATE" '
  .instincts_sent = {session: $s,
    lines: ((if (.instincts_sent.session // "") == $s then (.instincts_sent.lines // []) else [] end) + $new | unique)}' \
  --arg s "$DF_SESSION" --argjson new "$NEW"
df_gitignore ".devflow-observe-state.json"
ENTRIES=$(printf '%s' "$NEW" | jq -r '.[]')

CONTEXT="🧠 Instincts relevant to $BASENAME:

$ENTRIES"

df_context "$CONTEXT"
exit 0
