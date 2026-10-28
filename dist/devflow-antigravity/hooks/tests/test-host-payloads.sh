#!/bin/bash
# test-host-payloads.sh — every hook against real host payload shapes.
# Fixtures: tests/fixtures/claude/*.json (Claude Code hook input schema) and
# tests/fixtures/antigravity/*.json (captured from agy). __WS__ / __HOME__ are
# replaced with a scratch workspace before each run.
#   1. lib/payload.sh parses both shapes into the same DF_* variables
#   2. guards deny the destructive fixtures in each host's output format
#   3. smoke: every hook × every fixture exits 0 and prints nothing or one
#      valid JSON object (never echoes its input)
# Usage: bash templates/devflow/hooks/tests/test-host-payloads.sh

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$HOOKS_DIR/tests/fixtures"
PASS=0
FAIL=0
ERRORS=()

assert() {
  local label="$1" result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1)); echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1)); ERRORS+=("FAIL: $label"); echo "  FAIL: $label"
  fi
}

WS=$(mktemp -d); WS=$(cd "$WS" && pwd -P)
trap 'rm -rf "$WS"' EXIT
(cd "$WS" && git init -q 2>/dev/null) || true

fixture() {
  sed -e "s|__WS__|$WS|g" -e "s|__HOME__|$HOME|g" "$FIX/$1"
}

# parse <fixture> [env...] — print DF_* as key=value lines
parse() {
  local f="$1"; shift
  fixture "$f" | (cd /tmp && env "$@" bash -c '. "$1/lib/payload.sh"; df_read_input; printf "host=%s\nevent=%s\ntool=%s\nfile=%s\ncmd=%s\nerr=%s\nsession=%s\nws=%s\ntranscript=%s\n" "$DF_HOST" "$DF_EVENT" "$DF_TOOL" "$DF_FILE" "$DF_CMD" "$DF_IS_ERROR" "$DF_SESSION" "$DF_WORKSPACE" "$DF_TRANSCRIPT"' _ "$HOOKS_DIR")
}

field() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }

echo "=== test-host-payloads.sh ==="
echo ""

echo "--- T1: Claude Code payloads ---"
p=$(parse claude/pre-bash.json)
[ "$(field "$p" host)" = "claude" ] && [ "$(field "$p" event)" = "PreToolUse" ] && [ "$(field "$p" tool)" = "shell" ] \
  && assert "pre-bash: host/event/tool" pass || assert "pre-bash: host/event/tool ($p)" fail
[ "$(field "$p" cmd)" = "git reset --hard HEAD~1" ] && assert "pre-bash: command" pass || assert "pre-bash: command" fail
[ "$(field "$p" ws)" = "$WS" ] && assert "workspace from payload cwd, not hook cwd" pass || assert "workspace from payload cwd ($(field "$p" ws))" fail
p=$(parse claude/post-edit.json)
[ "$(field "$p" tool)" = "write" ] && [ "$(field "$p" file)" = "$WS/src/app.ts" ] \
  && assert "post-edit: write + file_path" pass || assert "post-edit: write + file_path ($p)" fail
p=$(parse claude/post-failure.json)
[ "$(field "$p" err)" = "true" ] && assert "PostToolUseFailure → is_error true" pass || assert "PostToolUseFailure → is_error true" fail
p=$(parse claude/pre-agent.json)
[ "$(field "$p" tool)" = "subagent" ] && assert "Agent → subagent" pass || assert "Agent → subagent" fail

echo "--- T2: Antigravity payloads ---"
p=$(parse antigravity/stop.json DEVFLOW_EVENT=Stop)
[ "$(field "$p" host)" = "antigravity" ] && [ "$(field "$p" event)" = "Stop" ] \
  && assert "agy stop: host detected, event from DEVFLOW_EVENT" pass || assert "agy stop: host/event ($p)" fail
[ "$(field "$p" ws)" = "$WS" ] && assert "agy: workspace from workspacePaths[0]" pass || assert "agy: workspace ($(field "$p" ws))" fail
[ "$(field "$p" session)" = "2846e312-b405-43b3-b0d8-7300cbdc3b2e" ] && [ "$(field "$p" transcript)" = "$WS/transcript_full.jsonl" ] \
  && assert "agy: conversationId + transcriptPath" pass || assert "agy: conversationId + transcriptPath" fail
p=$(printf '{"conversationId":"c","workspacePaths":["%s"],"toolName":"run_command","toolInput":{"CommandLine":"rm -rf /"}}' "$WS" \
  | (cd /tmp && bash -c '. "$1/lib/payload.sh"; df_read_input; echo "tool=$DF_TOOL"; echo "cmd=$DF_CMD"' _ "$HOOKS_DIR"))
[ "$(field "$p" tool)" = "shell" ] && [ "$(field "$p" cmd)" = "rm -rf /" ] \
  && assert "agy tool shape (best-effort): run_command/CommandLine" pass || assert "agy tool shape ($p)" fail

p=$(parse antigravity/pre-tool-write.json DEVFLOW_EVENT=PreToolUse)
[ "$(field "$p" tool)" = "write" ] && [ "$(field "$p" file)" = "$WS/b.txt" ] \
  && assert "agy captured write_file: toolCall.args.Path" pass || assert "agy captured write_file ($p)" fail
p=$(parse antigravity/post-tool-read.json DEVFLOW_EVENT=PostToolUse)
[ "$(field "$p" tool)" = "read" ] && [ "$(field "$p" err)" = "false" ] \
  && assert "agy captured read_file post: error \"\" → false" pass || assert "agy captured read_file post ($p)" fail

echo "--- T3: guards deny in each host's format ---"
out=$(fixture claude/pre-bash.json | bash "$HOOKS_DIR/pre-bash-destructive-guard.sh")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
  && assert "Claude Code: permissionDecision deny" pass || assert "Claude Code deny ($out)" fail
out=$(fixture claude/pre-edit.json | bash "$HOOKS_DIR/pre-config-protect.sh")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
  && assert "Claude Code: tsconfig.json edit denied" pass || assert "tsconfig deny ($out)" fail
out=$(printf '{"conversationId":"c","workspacePaths":["%s"],"toolName":"run_command","toolInput":{"CommandLine":"git reset --hard"}}' "$WS" \
  | DEVFLOW_EVENT=PreToolUse bash "$HOOKS_DIR/pre-bash-destructive-guard.sh")
printf '%s' "$out" | jq -e '.decision == "deny"' >/dev/null 2>&1 \
  && assert "Antigravity: decision deny" pass || assert "Antigravity deny ($out)" fail

out=$(fixture antigravity/pre-tool-write.json | sed 's|/b.txt"|/tsconfig.json"|' | DEVFLOW_EVENT=PreToolUse bash "$HOOKS_DIR/pre-config-protect.sh")
printf '%s' "$out" | jq -e '.decision == "deny"' >/dev/null 2>&1 \
  && assert "Antigravity: captured write_file on tsconfig.json denied" pass || assert "Antigravity tsconfig deny ($out)" fail

echo "--- T4: every hook × every fixture: exit 0, no echo, JSON or nothing ---"
HOOK_ARGS=(
  "session-start.sh" "session-start-learnings.sh" "pre-config-protect.sh" "pre-scope-guard.sh"
  "pre-bash-destructive-guard.sh" "pre-fetch-cache.sh" "pre-agent-fanout-cap.sh" "observe.sh pre"
  "observe.sh post" "observe.sh stop" "post-bash-output-filter.sh" "post-edit-accumulate.sh"
  "post-edit-instinct-context.sh" "post-task-create.sh" "post-fetch-cache.sh" "pre-model-switch.sh"
  "post-model-switch.sh" "pre-compact.sh" "stop-format-typecheck.sh" "stop-debug-check.sh"
  "stop-learn-distill.sh" "stop-metrics.sh"
)
SMOKE_FAIL=""
for fx in "$FIX"/claude/*.json "$FIX"/antigravity/*.json; do
  rel="${fx#"$FIX"/}"
  for h in "${HOOK_ARGS[@]}"; do
    # shellcheck disable=SC2086
    out=$(fixture "$rel" | (cd /tmp && DEVFLOW_EVENT=Stop bash "$HOOKS_DIR"/$h 2>/dev/null)); rc=$?
    if [ "$rc" -ne 0 ]; then SMOKE_FAIL="$SMOKE_FAIL $h<$rel:rc=$rc"; continue; fi
    [ -z "$out" ] && continue
    if ! printf '%s' "$out" | jq -e 'type == "object"' >/dev/null 2>&1; then
      SMOKE_FAIL="$SMOKE_FAIL $h<$rel:non-json"
    elif printf '%s' "$out" | jq -e 'has("hook_event_name") or has("conversationId")' >/dev/null 2>&1; then
      SMOKE_FAIL="$SMOKE_FAIL $h<$rel:echoed-input"
    fi
  done
done
[ -z "$SMOKE_FAIL" ] && assert "all hooks well-behaved on all fixtures" pass || assert "smoke:$SMOKE_FAIL" fail
[ ! -e /tmp/.devflow-state.json ] && [ ! -e /tmp/.devflow-observe.jsonl ] \
  && assert "hooks wrote into the payload workspace, not their own cwd" pass \
  || assert "hooks wrote into their own cwd (/tmp)" fail

echo "--- T5: changed-file accumulator matches whole paths ---"
rm -f "$WS/.devflow-changed-files.tmp"
for f in src/data.ts src/a.ts src/a.ts; do
  jq -cn --arg cwd "$WS" --arg f "$WS/$f" '{hook_event_name:"PostToolUse",cwd:$cwd,tool_name:"Edit",tool_input:{file_path:$f}}' \
    | bash "$HOOKS_DIR/post-edit-accumulate.sh"
done
[ "$(wc -l < "$WS/.devflow-changed-files.tmp" | tr -d ' ')" = "2" ] \
  && assert "a.ts recorded despite data.ts, duplicates skipped" pass \
  || assert "a.ts recorded despite data.ts ($(cat "$WS/.devflow-changed-files.tmp"))" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
