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

ENTRIES=$(
  yq -r \
    ".instincts // [] | map(select(.confidence >= ${MIN_CONFIDENCE})) | map(select((.domain // \"general\") == \"${DOMAIN}\" or (.trigger // \"\") == \"when editing ${FILE_PATH}\" or (.trigger // \"\") | test(\"${BASENAME}\"))) | sort_by(.confidence) | reverse | .[0:${MAX_SHOW}] | .[] | \"• [\" + (.confidence | tostring) + \" \" + (.domain // \"general\") + \"] \" + .trigger + \" → \" + .action" \
    "$INSTINCTS_FILE" 2>/dev/null
) || true

[[ -z "$ENTRIES" ]] && exit 0

CONTEXT="🧠 Instincts relevant to $BASENAME:

$ENTRIES"

df_context "$CONTEXT"
exit 0
