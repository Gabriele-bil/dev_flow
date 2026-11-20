#!/bin/bash
# test-review-packet.sh — Behavioral tests for review-packet.sh: diff against
# the base branch with uncommitted and new files, devflow/ excluded, spec
# excerpts, project rules, diff cap.
# Usage: bash templates/devflow/scripts/test-review-packet.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RP="$SCRIPT_DIR/review-packet.sh"

PASS=0
FAIL=0
T=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }
assert_equals() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got='$2' want='$3'"; fi; }
has() { if grep -qF -- "$3" "$2"; then pass "$1"; else fail "$1" "'$3' not in $2"; fi; }
hasnt() { if grep -qF -- "$3" "$2"; then fail "$1" "'$3' found in $2"; else pass "$1"; fi; }

setup() {
  T=$(mktemp -d)
  cd "$T" || exit 1
  git init -q -b main && git config user.email t@t && git config user.name t
  printf 'export const a = 1;\n' > a.ts; printf 'node_modules/\n' > .gitignore
  printf '# Constitution\n\n- Layering: ui → domain → data\n' > constitution.md
  printf '| Name | Path |\n| UserCard | src/user-card.tsx |\n| Unrelated | src/other.ts |\n' > REGISTRY.md
  git add -A && git commit -qm base
  git checkout -qb feat/001_cards
  mkdir -p devflow/features/001_cards src
  cat > devflow/features/001_cards/task.md <<'EOF'
# Task

**Status:** clarified

## Acceptance Criteria

- AC-1: the card shows the user name

## Scope Boundaries

- No avatar upload
EOF
  cat > devflow/features/001_cards/plan.md <<'EOF'
# Plan

**Status:** tested
**Complexity:** 6 (standard)

## Traceability

| AC-1 | src/user-card.tsx |

## File List

### 001. `src/user-card.tsx` - create [done]
EOF
  printf 'export const a = 2;\n' > a.ts && git commit -qam "change a"
  printf 'export const b = 1;\n' >> a.ts
  printf 'export function UserCard() {}\n' > src/user-card.tsx
}
teardown() { cd / && rm -rf "$T"; }

echo "── review-packet.sh ────────────────────────────────────"

setup
out=$(bash "$RP" 2>&1)
P=.devflow-review-packet.md
case "$out" in "review packet: $P · 001_cards · tree "*" · 3 files"*) pass "summary line (a.ts, user-card.tsx, .gitignore entry)" ;; *) fail "summary line" "$out" ;; esac
has "base resolved to local main" $P "base: main"
has "committed change in diff" $P "-export const a = 1;"
has "uncommitted change in diff" $P "+export const b = 1;"
has "untracked new file listed" $P "src/user-card.tsx"
has "untracked new file in diff" $P "+export function UserCard() {}"
hasnt "devflow/ excluded from changed files" $P "devflow/features/001_cards/plan.md"
has "acceptance criteria extracted" $P "AC-1: the card shows the user name"
has "scope boundaries extracted" $P "No avatar upload"
has "traceability extracted" $P "| AC-1 | src/user-card.tsx |"
hasnt "file list not copied" $P "## File List"
has "depth profile from Complexity" $P "Depth profile: standard"
has "small constitution inlined" $P "Layering: ui → domain → data"
has "registry entry for changed file" $P "| UserCard | src/user-card.tsx |"
hasnt "registry entry for unchanged file left out" $P "| Unrelated |"
has "packet gitignored" .gitignore ".devflow-review-packet.md"
assert_equals "real index untouched" "$(git diff --cached --name-only)" ""
teardown

setup
for i in $(seq 1 400); do echo "line $i of a long generated file" ; done > src/big.ts
bash "$RP" --max-diff-kb 2 --profile thorough --roster "code-reviewer security-auditor" >/dev/null 2>&1
has "diff cap announced" .devflow-review-packet.md "Cut at 2 KB"
has "diff cap: cut file named" .devflow-review-packet.md "- src/big.ts"
has "profile and roster flags" .devflow-review-packet.md "Depth profile: thorough · roster: code-reviewer security-auditor"
printf '# Notes\n' > NOTES.md && mkdir -p test && printf 'it();\n' > test/a_test.ts
bash "$RP" >/dev/null 2>&1
assert_equals "diff order: source, then tests, then docs" \
  "$(grep '^diff --git' .devflow-review-packet.md | awk '{print $NF}' | tr '\n' ' ')" \
  "b/a.ts b/src/big.ts b/src/user-card.tsx b/test/a_test.ts b/.gitignore b/NOTES.md "
teardown

setup
bash "$RP" >/dev/null 2>&1
TREE1=$(grep -m1 '^- Tree: ' .devflow-review-packet.md | sed 's/^- Tree: \([0-9a-f]*\).*/\1/')
printf 'export function UserCard() { return 1 }\n' > src/user-card.tsx
out=$(bash "$RP" --since "$TREE1" 2>&1)
case "$out" in *"1 files"*) pass "since: only the file changed after the first review" ;; *) fail "since: only the file changed after the first review" "$out" ;; esac
hasnt "since: earlier changes left out" .devflow-review-packet.md "+export const b = 1;"
has "since: incremental header" .devflow-review-packet.md "**Incremental:**"
bash "$RP" --since deadbeef >/dev/null 2>&1; assert_equals "since: bad tree → exit 1" "$?" "1"
teardown

setup
for i in $(seq 1 400); do echo "  final int f$i = $i;"; done > src/model.freezed.dart
printf 'lockfileVersion: 9\n' > pnpm-lock.yaml
printf 'export const legacy = 1;\n' > src/vendor.ts && printf 'src/vendor.ts linguist-generated\n' > .gitattributes
bash "$RP" --max-diff-kb 2 >/dev/null 2>&1
P=.devflow-review-packet.md
hasnt "generated: diff not cut by generated code" $P "Cut at 2 KB"
hasnt "generated: freezed body left out" $P "final int f1 = 1;"
has "generated: listed with the count" $P "Generated / lockfiles (3)"
has "generated: lockfile listed" $P "- pnpm-lock.yaml"
has "generated: linguist-generated listed" $P "- src/vendor.ts"
has "generated: authored code still diffed" $P "+export const b = 1;"
teardown

T=$(mktemp -d); cd "$T" || exit 1; git init -q
bash "$RP" >/dev/null 2>&1; assert_equals "no feature → exit 1" "$?" "1"
cd / && rm -rf "$T"

echo ""
echo "review-packet: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
