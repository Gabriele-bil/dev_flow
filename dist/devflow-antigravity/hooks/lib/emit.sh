#!/usr/bin/env bash
# lib/emit.sh — host-correct hook output. Requires lib/payload.sh (DF_HOST, DF_EVENT).
#
# Claude Code contract (code.claude.com/docs/en/hooks):
#   PreToolUse deny   → hookSpecificOutput.permissionDecision = "deny"
#   context for Claude → hookSpecificOutput.additionalContext
#                        (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse)
#   message for user  → top-level systemMessage (any event; the only visible
#                        channel for Stop / PreCompact)
#   stderr with exit 0 reaches nobody — never use it to talk to Claude.
# Antigravity CLI: pre-tool hooks return a decision string; other output
#   channels are undocumented, so context/notices go to stderr (CLI log) and
#   static guidance ships as rules/ instead.

# df_deny <reason> — block the pending tool call. Caller exits 0 afterwards.
df_deny() {
  if [ "$DF_HOST" = "antigravity" ]; then
    jq -cn --arg r "$1" '{decision: "deny", reason: $r}'
  else
    jq -cn --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  fi
}

# df_context <text> — add context for the model. Falls back to systemMessage on
# events where Claude Code does not accept additionalContext.
df_context() {
  if [ "$DF_HOST" = "antigravity" ]; then
    printf '%s\n' "$1" >&2
    return 0
  fi
  case "$DF_EVENT" in
    SessionStart|UserPromptSubmit|PreToolUse|PostToolUse|PostToolUseFailure)
      jq -cn --arg e "$DF_EVENT" --arg c "$1" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $c}}'
      ;;
    *)
      jq -cn --arg c "$1" '{systemMessage: $c}'
      ;;
  esac
}

# df_notify <text> — short notice shown to the user (not added to context).
df_notify() {
  if [ "$DF_HOST" = "antigravity" ]; then
    printf '%s\n' "$1" >&2
    return 0
  fi
  jq -cn --arg m "$1" '{systemMessage: $m}'
}
