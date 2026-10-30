#!/bin/bash
# test-devflow-state.sh — Behavioral tests for devflow-state.sh: feature
# resolution, legal transitions, File List markers, checkpoint append, run marker.
# Usage: bash templates/devflow/scripts/test-devflow-state.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_SH="$SCRIPT_DIR/devflow-state.sh"

PASS=0
FAIL=0
T=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

assert_equals() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then pass "$label"; else fail "$label" "'$needle' not in: $haystack"; fi
}

st() { bash "$STATE_SH" "$@" 2>&1; }

# feature <dir> <task-status> [plan-status] [blockers]
feature() {
  mkdir -p "devflow/features/$1"
  printf '# Task\n\n**Status:** %s\n**Branch:** feat/%s\n**Blockers:** %s\n' "$2" "$1" "${4:-none}" > "devflow/features/$1/task.md"
  if [ -n "${3:-}" ]; then
    printf '# Plan\n\n**Status:** %s\n**Complexity:** 3 (standard)\n\n## File List\n\n### 001. `src/a.ts` - create [done]\n### 002. `src/b.ts` - create [pending]\n### 003. [P] `src/c.ts` - modify [pending] [route: light]\n' "$3" > "devflow/features/$1/plan.md"
  fi
}

setup() {
  T=$(mktemp -d)
  cd "$T" || exit 1
  git init -q
  printf '.devflow-run.json.bak\n' > .gitignore
}

teardown() { cd / && rm -rf "$T"; }

echo "── devflow-state.sh ────────────────────────────────────"

# ── resolve ──────────────────────────────────────────────────────────────────
setup
feature 001_done "done" "" ; feature 002_login clarified implementing ; feature 003_profile draft
assert_equals "resolve: lowest open feature (terminal skipped)" "$(st resolve)" "002_login"
assert_equals "resolve: explicit NNN" "$(st resolve 003)" "003_profile"
assert_equals "resolve: explicit path" "$(st resolve devflow/features/003_profile/task.md)" "003_profile"
printf '{"feature":"003_profile"}' > .devflow-state.json
assert_equals "resolve: state file wins over lowest open" "$(st resolve)" "003_profile"
printf '{"active_feature":"002_login"}' > .devflow-state.json
assert_equals "resolve: legacy active_feature read" "$(st resolve)" "002_login"
rm .devflow-state.json
st resolve 999 >/dev/null; assert_equals "resolve: unknown explicit → exit 1" "$?" "1"
teardown

setup
feature 001_api clarified blocked ; feature 002_ui clarified ready 001 ; feature 003_docs draft
assert_equals "resolve: skips blocked and blocker-gated features" "$(st resolve)" "003_docs"
teardown

setup
st resolve >/dev/null; assert_equals "resolve: nothing → exit 1" "$?" "1"
teardown

# ── set ──────────────────────────────────────────────────────────────────────
setup
feature 004_cart clarified ready
out=$(st set plan implementing)
assert_contains "set: legal transition reported" "$out" "plan.md: ready → implementing"
assert_equals "set: plan.md Status rewritten" "$(grep -m1 '^\*\*Status' devflow/features/004_cart/plan.md)" "**Status:** implementing"
assert_equals "set: state cache plan_status" "$(jq -r .plan_status .devflow-state.json)" "implementing"
assert_equals "set: state cache next_step" "$(jq -r .next_step .devflow-state.json)" "devflow.implement"
assert_equals "set: progress counted from markers" "$(jq -c .progress .devflow-state.json)" '{"done":1,"pending":2,"total":3}'
assert_equals "set: branch from task.md" "$(jq -r .branch .devflow-state.json)" "feat/004_cart"
assert_equals "set: next_feature_number" "$(jq -r .next_feature_number .devflow-state.json)" "5"
out=$(st set plan shipped); rc=$?
assert_equals "set: illegal transition refused (exit 2)" "$rc" "2"
assert_contains "set: illegal transition explained" "$out" "not a legal transition"
assert_equals "set: refused transition leaves plan.md" "$(grep -m1 '^\*\*Status' devflow/features/004_cart/plan.md)" "**Status:** implementing"
st set plan implemented >/dev/null
out=$(st set plan tested); rc=$?
assert_equals "set: tested without verification.md refused" "$rc" "2"
printf '# Verification\n\n**Result:** FAIL\n' > devflow/features/004_cart/verification.md
st set plan tested >/dev/null; assert_equals "set: tested with FAIL verification refused" "$?" "2"
printf '# Verification\n\n**Result:** PASS\n' > devflow/features/004_cart/verification.md
out=$(st set plan tested)
assert_contains "set: hotfix fast-track implemented → tested" "$out" "implemented → tested"
st set plan ready >/dev/null; assert_equals "set: backward jump refused" "$?" "2"
out=$(st set plan ready --force)
assert_contains "set: --force allows user-confirmed reset" "$out" "tested → ready"
st set plan wip >/dev/null; assert_equals "set: unknown status refused" "$?" "2"
out=$(st set task "done")
assert_contains "set: task status" "$out" "task.md: clarified → done"
assert_equals "set: task_status cached" "$(jq -r .task_status .devflow-state.json)" "done"
printf '{"feature":"004_cart","custom":"keep","active_feature":"x"}' > .devflow-state.json
st set plan ready >/dev/null
assert_equals "set: unknown keys preserved" "$(jq -r .custom .devflow-state.json)" "keep"
assert_equals "set: legacy active_feature dropped" "$(jq -r '.active_feature // "gone"' .devflow-state.json)" "gone"
teardown

# ── mark-done ────────────────────────────────────────────────────────────────
setup
feature 005_feed clarified implementing
out=$(st mark-done src/c.ts)
assert_contains "mark-done: reports progress" "$out" "2/3 files"
assert_equals "mark-done: marker flipped, other markers kept" "$(grep -c '\[route: light\]' devflow/features/005_feed/plan.md)" "1"
assert_equals "mark-done: entry is [done]" "$(grep -c '`src/c.ts`.*\[done\]' devflow/features/005_feed/plan.md)" "1"
assert_contains "mark-done: idempotent" "$(st mark-done src/c.ts)" "already [done]"
st mark-done src/zzz.ts >/dev/null; assert_equals "mark-done: unknown path → exit 1" "$?" "1"
teardown

# ── checkpoint ───────────────────────────────────────────────────────────────
setup
feature 006_auth clarified implementing
st checkpoint --step devflow.implement --slice "Slice 1" --decision "repo pattern" --error "null mock" >/dev/null
out=$(st checkpoint --slice "Slice 2" --decision "repo pattern" --decision "batch calls")
CP=devflow/features/006_auth/.checkpoint.json
assert_contains "checkpoint: summary line" "$out" "Slice 2 · 2 decisions"
assert_equals "checkpoint: arrays appended, duplicates dropped, order kept" "$(jq -c .decisions $CP)" '["repo pattern","batch calls"]'
assert_equals "checkpoint: earlier errors kept" "$(jq -c .errors_tried $CP)" '["null mock"]'
assert_equals "checkpoint: step kept when not passed" "$(jq -r .step $CP)" "devflow.implement"
teardown

# ── report ───────────────────────────────────────────────────────────────────
setup
feature 008_rep clarified tested
F=devflow/features/008_rep
printf '\n## Deviations\n\n- `src/b.ts`: sync → async — API is async\n\n## Decision flags\n\n- picked cursor paging\n- kept REST\n' >> $F/plan.md
printf '**Result:** PARTIAL\n\n| # | AC | Verdict |\n|---|---|---|\n| 1 | a | PASS |\n| 2 | b | PARTIAL |\n| 3 | c | FAIL |\n' > $F/verification.md
out=$(st report)
assert_contains "report: feature line" "$out" "Feature:       008_rep · task: clarified · plan: tested"
assert_contains "report: create/modify counted" "$out" "2 create · 1 modify"
assert_contains "report: verification counted from verdicts" "$out" "PARTIAL — 2/3 ACs verified"
assert_contains "report: flags and deviations counted" "$out" "decision flags: 2 · deviations: 1"
assert_contains "report: no stamps yet" "$out" "Checks:        no stamps"
teardown

# ── run marker ───────────────────────────────────────────────────────────────
setup
out=$(st run arm --orchestrator devflow.auto --from task --until pr)
assert_contains "run arm: announced" "$out" "run armed: devflow.auto task → pr"
assert_equals "run arm: feature null until task.md" "$(jq -r .feature .devflow-run.json)" "null"
assert_equals "run arm: added to .gitignore" "$(grep -cx '.devflow-run.json' .gitignore)" "1"
st run arm --orchestrator devflow.run --from implement --until test >/dev/null
assert_equals "run arm: stale marker refused" "$?" "2"
st run feature 007_x >/dev/null
assert_equals "run feature: set" "$(jq -r .feature .devflow-run.json)" "007_x"
assert_contains "run bump: 1/2" "$(st run bump)" "grader iteration 1/2"
assert_contains "run bump: 2/2" "$(st run bump)" "grader iteration 2/2"
out=$(st run bump); rc=$?
assert_equals "run bump: cap reached → exit 3" "$rc" "3"
assert_contains "run status" "$(st run status)" "grader 2/2"
st run disarm >/dev/null
assert_equals "run disarm: marker removed" "$([ -e .devflow-run.json ] && echo present || echo gone)" "gone"
assert_equals "run status: inactive" "$(st run status)" "run: inactive"
teardown

echo ""
echo "devflow-state: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
