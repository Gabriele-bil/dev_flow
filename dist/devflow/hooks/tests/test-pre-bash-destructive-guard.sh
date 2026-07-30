#!/bin/bash
# test-pre-bash-destructive-guard.sh — Unit tests for pre-bash-destructive-guard.sh
# Usage: bash templates/devflow/hooks/tests/test-pre-bash-destructive-guard.sh
# Exit code: 0 = all pass, non-zero = failure

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/pre-bash-destructive-guard.sh"
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
  local command="$1"
  local payload
  payload=$(jq -cn --arg c "$command" '{tool_use: {name: "Bash", input: {command: $c}}}')
  printf '%s' "$payload" | bash "$HOOK" 2>/dev/null || true
}

expect_block() {
  local label="$1" command="$2"
  local out
  out=$(run_hook "$command")
  echo "$out" | grep -qE '"decision"[[:space:]]*:[[:space:]]*"block"' \
    && assert "$label blocked" pass \
    || assert "$label blocked (output: '$out')" fail
}

expect_allow() {
  local label="$1" command="$2"
  local out
  out=$(run_hook "$command")
  [ -z "$out" ] \
    && assert "$label allowed" pass \
    || assert "$label allowed (unexpected output: '$out')" fail
}

echo "=== test-pre-bash-destructive-guard.sh ==="
echo ""

echo "--- T1: catastrophic rm -rf blocked ---"
expect_block "rm -rf /"          "rm -rf /"
expect_block "rm -rf ~"          "rm -rf ~"
expect_block "rm -rf ."          "rm -rf ."
expect_block "rm -rf .."         "rm -rf .."
expect_block "rm -rf *"          "rm -rf *"

echo "--- T2: git hard-reset / clean / discard blocked ---"
expect_block "git reset --hard"  "git reset --hard HEAD~1"
expect_block "git clean -fd"     "git clean -fd"
expect_block "git checkout -- ." "git checkout -- ."
expect_block "git restore ."     "git restore ."

echo "--- T3: force-push to protected branch blocked ---"
expect_block "push --force origin main"   "git push --force origin main"
expect_block "push -f origin master"      "git push -f origin master"
expect_block "bare push --force (on main)" "git push --force"

echo "--- T4: commit hook/signature bypass blocked ---"
expect_block "commit --no-verify"    "git commit -m x --no-verify"
expect_block "commit --no-gpg-sign"  "git commit --no-gpg-sign -m x"

echo "--- T5: scoped/normal commands allowed ---"
expect_allow "rm -rf node_modules"           "rm -rf node_modules"
expect_allow "rm -rf dist/build"             "rm -rf dist/build"
expect_allow "rm single file"                "rm file.txt"
expect_allow "git status"                    "git status"
expect_allow "push to feature branch"        "git push origin feature-branch"
expect_allow "force-push to feature branch"  "git push --force origin feature-branch"
expect_allow "normal commit"                 "git commit -m 'normal commit'"
expect_allow "git log"                       "git log --oneline"
expect_allow "npm install"                   "npm install"
expect_allow "soft git reset"                "git reset HEAD~1"

echo "--- T6: degenerate input allowed silently ---"
out=$(printf '' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "empty stdin allowed" pass || assert "empty stdin allowed" fail
out=$(printf '{"tool_use":{"input":{}}}' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "missing command allowed" pass || assert "missing command allowed" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
