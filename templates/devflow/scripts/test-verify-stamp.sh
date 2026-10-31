#!/bin/bash
# test-verify-stamp.sh — Behavioral tests for verify-stamp.sh: tree-keyed
# freshness, failure output, test-count parsing, check/show for contracts.
# Usage: bash templates/devflow/scripts/test-verify-stamp.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VS="$SCRIPT_DIR/verify-stamp.sh"

PASS=0
FAIL=0
T=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }
assert_equals() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got='$2' want='$3'"; fi; }
assert_contains() { if printf '%s' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1" "'$3' not in: $2"; fi; }

vs() { bash "$VS" "$@" 2>&1; }

setup() {
  T=$(mktemp -d)
  cd "$T" || exit 1
  git init -q && git config user.email t@t && git config user.name t
  printf 'node_modules/\n' > .gitignore
  echo "a" > app.txt
  mkdir -p devflow/features/001_x && echo "**Status:** implementing" > devflow/features/001_x/plan.md
  git add -A && git commit -qm init
}
teardown() { cd / && rm -rf "$T"; }

echo "── verify-stamp.sh ─────────────────────────────────────"

setup
out=$(vs run lint -- true)
assert_contains "run: pass line" "$out" "✓ lint: pass"
assert_contains "run: second run on same tree skipped" "$(vs run lint -- true)" "✓ lint: fresh"
echo "**Status:** implemented" > devflow/features/001_x/plan.md
assert_contains "run: devflow/ edits keep the stamp fresh" "$(vs run lint -- true)" "fresh"
echo "b" > app.txt
assert_contains "run: code edit makes it stale → re-run" "$(vs run lint -- true)" "✓ lint: pass"
echo "new" > untracked.txt
assert_contains "run: untracked file makes it stale" "$(vs run lint -- true)" "✓ lint: pass"
mkdir -p node_modules && echo x > node_modules/x.js
assert_contains "run: ignored files do not count" "$(vs run lint -- true)" "fresh"
assert_contains "run: --force re-runs" "$(vs run lint --force -- true)" "✓ lint: pass"
mkdir -p sub
assert_contains "run: different --cwd re-runs" "$(vs run lint --cwd sub -- true)" "✓ lint: pass"
assert_equals "run: index untouched" "$(git status --porcelain app.txt)" " M app.txt"
teardown

setup
out=$(vs run analyze -- sh -c 'echo "error TS2304: cannot find name"; exit 2'); rc=$?
assert_equals "fail: exit code propagated" "$rc" "2"
assert_contains "fail: result line" "$out" "✗ analyze: FAIL exit 2"
assert_contains "fail: decisive lines shown" "$out" "error TS2304"
assert_contains "fail: never reported fresh" "$(vs run analyze -- true)" "✓ analyze: pass"
out=$(vs run build -- sh -c 'for i in $(seq 1 100); do echo "line $i"; done; exit 1')
assert_contains "fail: long output trimmed" "$out" "60 lines in .devflow-verify/build.log"
assert_equals "fail: full output kept in log" "$(wc -l < .devflow-verify/build.log | tr -d ' ')" "100"
assert_contains "log: stamp and logs gitignored" "$(cat .gitignore)" ".devflow-verify/"
teardown

setup
assert_contains "counts: jest" "$(vs run test -- sh -c 'echo "Tests:       1 failed, 41 passed, 42 total"')" "41 passed · 1 failed · 0 skipped"
assert_contains "counts: flutter" "$(vs run test:unit -- sh -c 'echo "00:03 +40 ~1 -2: Some tests failed."')" "40 passed · 2 failed · 1 skipped"
assert_contains "counts: pytest" "$(vs run test:py -- sh -c 'echo "==== 12 passed, 3 skipped in 0.5s ===="')" "12 passed · 0 failed · 3 skipped"
assert_contains "counts: vitest" "$(vs run e2e -- sh -c 'echo " Tests  7 passed (7)"')" "7 passed · 0 failed"
assert_contains "counts: shown again when fresh" "$(vs run test -- true)" "41 passed"
teardown

setup
vs run test:auth -- true >/dev/null
vs check test >/dev/null; assert_equals "check: subset never counts as full test" "$?" "1"
vs run test -- true >/dev/null
assert_contains "check: fresh pass" "$(vs check test)" "✓ test: fresh pass"
vs check >/dev/null; assert_equals "check: no lint/analyze stamp → not verified" "$?" "1"
vs run analyze -- true >/dev/null
vs check >/dev/null; assert_equals "check: analyze + all stamps on tree pass" "$?" "0"
vs run lint -- false >/dev/null
vs check >/dev/null; assert_equals "check: a failing stamp on this tree → not clean" "$?" "1"
assert_contains "check: prefix → every test* stamp fresh" "$(vs check 'test*')" "✓ test*: fresh pass"
vs check 'e2e*' >/dev/null; assert_equals "check: prefix with nothing stamped fails" "$?" "1"
echo c > app.txt
assert_contains "check: stale after edit" "$(vs check test)" "✗ test: stale"
assert_contains "check: prefix names the stale stamps" "$(vs check 'test*')" "test:auth, test"
assert_contains "show: lists stamps" "$(vs show)" "test: pass · stale"
teardown

setup
vs run tests -- true >/dev/null; assert_equals "name: invalid name rejected (64)" "$?" "64"
vs run lint >/dev/null; assert_equals "name: missing command rejected (64)" "$?" "64"
vs run analyze@web --cwd nope -- true >/dev/null; assert_equals "cwd: missing dir rejected (64)" "$?" "64"
teardown

T=$(mktemp -d); cd "$T" || exit 1
assert_contains "no git: still runs" "$(vs run lint -- true)" "✓ lint: pass"
assert_contains "no git: never fresh" "$(vs run lint -- true)" "✓ lint: pass"
cd / && rm -rf "$T"

echo ""
echo "verify-stamp: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
