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
  local branch="${2:-${DEVFLOW_CURRENT_BRANCH:-}}"
  local payload
  payload=$(jq -cn --arg c "$command" '{hook_event_name: "PreToolUse", session_id: "s1", tool_name: "Bash", tool_input: {command: $c}}')
  printf '%s' "$payload" | DEVFLOW_CURRENT_BRANCH="$branch" bash "$HOOK" 2>/dev/null || true
}

expect_block() {
  local label="$1" command="$2" branch="${3:-${DEVFLOW_CURRENT_BRANCH:-}}"
  local out
  out=$(run_hook "$command" "$branch")
  echo "$out" | grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"' \
    && assert "$label blocked" pass \
    || assert "$label blocked (output: '$out')" fail
}

expect_allow() {
  local label="$1" command="$2" branch="${3:-${DEVFLOW_CURRENT_BRANCH:-}}"
  local out
  out=$(run_hook "$command" "$branch")
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
expect_block "bare push --force (on main)" "git push --force" "main"

echo "--- T4: commit hook/signature bypass blocked ---"
expect_block "commit --no-verify"    "git commit -m x --no-verify"
expect_block "commit --no-gpg-sign"  "git commit --no-gpg-sign -m x"

echo "--- T4b: bypasses of the naive patterns ---"
expect_block "rm -rf /*"                  "rm -rf /*"
expect_block 'rm -rf "$HOME"'             'rm -rf "$HOME"'
expect_block 'rm -rf ${HOME}/'            'rm -rf ${HOME}/'
expect_block "rm -r -f /"                 "rm -r -f /"
expect_block "rm --recursive --force ~"   "rm --recursive --force ~"
expect_block "sudo rm -fr /"              "sudo rm -fr /"
expect_block "chained: cd x && rm -rf ."  "cd x && rm -rf ."
expect_block "git -C . reset --hard"      "git -C . reset --hard"
expect_block "git -c x=y reset --hard"    "git -c color.ui=false reset --hard"
expect_block "git push origin +main"      "git push origin +main"
expect_block "git push origin +HEAD:main" "git push origin +HEAD:main"
expect_block "git push -uf origin main"   "git push -uf origin main"
expect_block "git commit -n"              "git commit -n -m x"
expect_block "git commit -anm"            "git commit -anm x"
expect_block "git -c core.hooksPath"      "git -c core.hooksPath=/dev/null commit -m x"
expect_block "git checkout -f"            "git checkout -f"

echo "--- T5: scoped/normal commands allowed ---"
expect_allow "message mentioning -n"             "git commit -m 'fix -n flag'"
expect_allow "rm -rf ./build"                    "rm -rf ./build"
expect_allow "rm -rf \$HOME/.cache/foo"          'rm -rf $HOME/.cache/foo'
expect_allow "push +feature"                     "git push origin +feature-x"
expect_allow "git -C repo status"                "git -C repo status"
expect_allow "rm -rf node_modules"               "rm -rf node_modules"
expect_allow "rm -rf dist/build"                 "rm -rf dist/build"
expect_allow "rm single file"                    "rm file.txt"
expect_allow "git status"                        "git status"
expect_allow "push to feature branch"            "git push origin feature-branch"
expect_allow "force-push to feature branch"      "git push --force origin feature-branch"
expect_allow "bare force-push on feature branch" "git push --force" "feature-branch"
expect_allow "normal commit"                     "git commit -m 'normal commit'"
expect_allow "git log"                           "git log --oneline"
expect_allow "npm install"                       "npm install"
expect_allow "soft git reset"                    "git reset HEAD~1"

echo "--- T6: degenerate input allowed silently ---"
out=$(printf '' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "empty stdin allowed" pass || assert "empty stdin allowed" fail
out=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}' | bash "$HOOK" 2>/dev/null || true)
[ -z "$out" ] && assert "missing command allowed" pass || assert "missing command allowed" fail

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""; echo "Failures:"; for e in "${ERRORS[@]}"; do echo "  $e"; done
  exit 1
fi
exit 0
