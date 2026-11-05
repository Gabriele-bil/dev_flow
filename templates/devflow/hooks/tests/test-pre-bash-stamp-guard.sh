#!/bin/bash
# test-pre-bash-stamp-guard.sh — Unit tests for pre-bash-stamp-guard.sh
# Usage: bash templates/devflow/hooks/tests/test-pre-bash-stamp-guard.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-bash-stamp-guard.sh"
WS="$(mktemp -d)"
trap 'rm -rf "$WS"' EXIT
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

run_hook() {
  local payload
  payload=$(jq -cn --arg c "$1" --arg cwd "$WS" '{hook_event_name: "PreToolUse", session_id: "s1", cwd: $cwd, tool_name: "Bash", tool_input: {command: $c}}')
  printf '%s' "$payload" | DEVFLOW_WORKSPACE="$WS" bash "$HOOK" 2>/dev/null || true
}

run_hook_agy() {
  local payload
  payload=$(jq -cn --arg c "$1" --arg ws "$WS" '{conversationId: "c1", workspacePaths: [$ws], stepIdx: 1, toolCall: {name: "run_command", args: {CommandLine: $c}}}')
  printf '%s' "$payload" | DEVFLOW_EVENT=PreToolUse DEVFLOW_WORKSPACE="$WS" bash "$HOOK" 2>/dev/null || true
}

expect_block() {
  local out
  out=$(run_hook "$2")
  echo "$out" | grep -q '"permissionDecision":"deny"' \
    && assert "$1 blocked" pass \
    || assert "$1 blocked (output: '$out')" fail
}

expect_allow() {
  local out
  out=$(run_hook "$2")
  [ -z "$out" ] \
    && assert "$1 allowed" pass \
    || assert "$1 allowed (unexpected output: '$out')" fail
}

echo "=== test-pre-bash-stamp-guard.sh ==="
echo ""

echo "--- T1: no run marker → never blocks ---"
rm -f "$WS/.devflow-run.json"
expect_allow "pnpm test (interactive)" "pnpm test"
expect_allow "flutter analyze (interactive)" "flutter analyze"

echo "--- T2: run mode, raw checks blocked ---"
echo '{"active":true}' > "$WS/.devflow-run.json"
expect_block "pnpm test"                    "pnpm test"
expect_block "pnpm --filter app test"       "pnpm --filter idp-server test"
expect_block "pnpm --filter app run test"   "pnpm --filter @nexus/database run test"
expect_block "npm run lint"                 "npm run lint"
expect_block "npm t"                        "npm t"
expect_block "yarn test:e2e"                "yarn test:e2e"
expect_block "pnpm exec tsc"                "pnpm exec tsc --noEmit"
expect_block "npx eslint"                   "npx eslint src"
expect_block "npx playwright test"          "npx playwright test"
expect_block "ng build"                     "ng build"
expect_block "flutter test"                 "flutter test"
expect_block "dart analyze"                 "dart analyze"
expect_block "cd then test"                 "cd apps/web && pnpm test"
expect_block "piped test"                   "pnpm test 2>&1 | tail -20"
expect_block "env prefix"                   "CI=1 pnpm test"

echo "--- T3: run mode, non-checks and stamped checks allowed ---"
expect_allow "stamped test"        "bash \"\$HOME/.claude/plugins/devflow/scripts/verify-stamp.sh\" run test -- pnpm test"
expect_allow "pnpm install"        "pnpm install"
expect_allow "pnpm exec node"      "pnpm --filter @nexus/database exec node -e 'console.log(1)'"
expect_allow "git status"          "git status --short"
expect_allow "commit message"      "git commit -m \"fix: pnpm test flake\""
expect_allow "help flag"           "pnpm test --help"
expect_allow "flutter pub get"     "flutter pub get"
expect_allow "playwright install"  "npx playwright install"

echo "--- T4: disabled by env ---"
out=$(printf '%s' "$(jq -cn --arg cwd "$WS" '{hook_event_name:"PreToolUse",cwd:$cwd,tool_name:"Bash",tool_input:{command:"pnpm test"}}')" \
  | DEVFLOW_STAMP_GUARD=off DEVFLOW_WORKSPACE="$WS" bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "DEVFLOW_STAMP_GUARD=off allows" pass || assert "DEVFLOW_STAMP_GUARD=off allows (output: '$out')" fail

echo "--- T5: Antigravity payload ---"
out=$(run_hook_agy "pnpm --filter idp-server test")
echo "$out" | grep -q '"decision":"deny"' && assert "agy run_command blocked" pass || assert "agy run_command blocked (output: '$out')" fail
out=$(run_hook_agy "git status")
[ -z "$out" ] && assert "agy git status allowed" pass || assert "agy git status allowed (output: '$out')" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '%s\n' "${ERRORS[@]}"
  exit 1
fi
exit 0
