#!/usr/bin/env bash
# review-packet.sh — one file with everything devflow.ship reviewers read
# first: changed files, diff (committed + uncommitted + new files, against the
# base branch), acceptance criteria, plan excerpts, verification stamps and the
# project rules. Every agent reads the packet instead of re-running git diff
# and re-reading task.md, plan.md and constitution.md. Identical on both hosts.
#
# Usage (from the project root):
#   review-packet.sh [feature] [--base BRANCH] [--profile P] [--roster "a b c"] [--max-diff-kb N]
# Writes .devflow-review-packet.md (gitignored) and prints one summary line.
# Diff over --max-diff-kb (default 80) is cut; the packet names the files to
# open instead. Exit 1: no feature resolved.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/lib/payload.sh
. "$SCRIPT_DIR/../hooks/lib/payload.sh"

DF_WORKSPACE="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$DF_WORKSPACE" || exit 1
OUT=".devflow-review-packet.md"

FEATURE_ARG="" BASE="" PROFILE="" ROSTER="" MAX_KB=80
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --roster) ROSTER="$2"; shift 2 ;;
    --max-diff-kb) MAX_KB="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) FEATURE_ARG="$1"; shift ;;
  esac
done

FEATURE=$(bash "$SCRIPT_DIR/devflow-state.sh" resolve "$FEATURE_ARG" 2>/dev/null) || {
  echo "review-packet: no feature resolved${FEATURE_ARG:+ for '$FEATURE_ARG'}" >&2; exit 1; }
FDIR="devflow/features/$FEATURE"

field() { grep -m1 "^\*\*$2:\*\*" "$1" 2>/dev/null | sed "s/^\*\*$2:\*\*[[:space:]]*//; s/[[:space:]]*<!--.*//" | tr -d '\r'; }
# section <file> <heading-regex> — body of the first "## <heading>" up to the next "## ".
section() {
  awk -v re="^## +($2)" '
    $0 ~ re { on = 1; next }
    on && /^## / { exit }
    on { print }' "$1" 2>/dev/null | sed -e '/./,$!d'
}

# ── Base branch (same order as devflow.pr Step 0) ─────────────────────────────
if [ -z "$BASE" ]; then
  BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -z "$BASE" ]; then
    for c in main master develop next; do
      git show-ref --verify --quiet "refs/remotes/origin/$c" && { BASE="$c"; break; }
    done
  fi
  BASE="${BASE:-main}"
fi
BASE_REF=""
for r in "origin/$BASE" "$BASE"; do git rev-parse --verify --quiet "$r^{commit}" >/dev/null && { BASE_REF="$r"; break; }; done
MB=""
[ -n "$BASE_REF" ] && MB=$(git merge-base HEAD "$BASE_REF" 2>/dev/null)
[ -n "$MB" ] || MB=$(git rev-parse --verify --quiet HEAD 2>/dev/null)
[ -n "$MB" ] || MB=4b825dc642cb6eb9a060e54bf8d69288fbee4904  # empty tree: no commit yet

# ── Diff: base → working tree, untracked files included (throwaway index) ────
IDX=$(mktemp "${TMPDIR:-/tmp}/devflow-index.XXXXXX")
REAL_IDX=$(git rev-parse --git-path index 2>/dev/null)
if [ -n "$REAL_IDX" ] && [ -f "$REAL_IDX" ]; then cp -p "$REAL_IDX" "$IDX"; else rm -f "$IDX"; fi
trap 'rm -f "$IDX"' EXIT
GIT_INDEX_FILE="$IDX" git add -A -- . ':(exclude)devflow' ':(exclude).devflow-*' >/dev/null 2>&1
PATHSPEC=(-- . ':(exclude)devflow' ':(exclude).devflow-*')
NAMES=$(GIT_INDEX_FILE="$IDX" git diff --cached --name-status "$MB" "${PATHSPEC[@]}" 2>/dev/null)
SUMMARY=$(GIT_INDEX_FILE="$IDX" git diff --cached --shortstat "$MB" "${PATHSPEC[@]}" 2>/dev/null | sed 's/^ *//')
DIFF=$(GIT_INDEX_FILE="$IDX" git diff --cached -U3 "$MB" "${PATHSPEC[@]}" 2>/dev/null)
NFILES=$(printf '%s' "$NAMES" | grep -c . || true)
DIFF_BYTES=${#DIFF}
CUT=""
if [ "$DIFF_BYTES" -gt $((MAX_KB * 1024)) ]; then
  DIFF=$(printf '%s' "$DIFF" | head -c $((MAX_KB * 1024)))
  CUT=1
fi

# ── Project rules ─────────────────────────────────────────────────────────────
first_existing() { local f; for f in "$@"; do [ -f "$f" ] && { echo "$f"; return; }; done; }
CONSTITUTION=$(first_existing constitution.md devflow/constitution.md docs/constitution.md)
REGISTRY=$(first_existing registry.md devflow/registry.md docs/registry.md)
REGISTRY_HITS=""
if [ -n "$REGISTRY" ] && [ -n "$NAMES" ]; then
  while IFS= read -r p; do
    b=$(basename "$p"); b="${b%%.*}"
    [ ${#b} -ge 3 ] && REGISTRY_HITS="$REGISTRY_HITS$(grep -F -- "$b" "$REGISTRY" 2>/dev/null)
"
  done <<EOF
$(printf '%s\n' "$NAMES" | awk '{print $NF}')
EOF
  REGISTRY_HITS=$(printf '%s' "$REGISTRY_HITS" | awk 'NF && !seen[$0]++')
fi

[ -n "$PROFILE" ] || PROFILE=$(field "$FDIR/plan.md" Complexity | grep -oE 'quick|standard|thorough' | head -1)
APP=$(field "$FDIR/plan.md" App)
STAMPS=$(bash "$SCRIPT_DIR/verify-stamp.sh" show 2>/dev/null)

# ── Write ─────────────────────────────────────────────────────────────────────
{
  echo "# Review packet — $FEATURE"
  echo
  echo "Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by scripts/review-packet.sh. Read this first; open source files only for the lines you need."
  echo
  echo "- Branch: $(git branch --show-current 2>/dev/null) · base: ${BASE_REF:-none} (merge-base ${MB:0:12})"
  echo "- Depth profile: ${PROFILE:-standard}${ROSTER:+ · roster: $ROSTER}${APP:+ · app: $APP}"
  echo "- Feature: $FDIR (task.md, plan.md, verification.md)"
  echo
  echo "## Verification stamps"
  echo
  echo '```text'; printf '%s\n' "${STAMPS:-no stamps}"; echo '```'
  echo
  echo "## Acceptance criteria (task.md)"
  echo
  section "$FDIR/task.md" "Acceptance Criteria"
  echo
  for h in "Scope Boundaries:task.md" "Architecture decisions:plan.md" "Traceability:plan.md" "Deviations:plan.md" "Decision flags:plan.md"; do
    name="${h%%:*}" file="${h##*:}"
    body=$(section "$FDIR/$file" "$name")
    [ -n "$body" ] || continue
    echo "## $name ($file)"; echo; printf '%s\n' "$body"; echo
  done
  echo "## Project rules"
  echo
  if [ -n "$CONSTITUTION" ] && [ "$(wc -c < "$CONSTITUTION")" -le 8192 ]; then
    echo "### $CONSTITUTION"; echo; cat "$CONSTITUTION"; echo
  elif [ -n "$CONSTITUTION" ]; then
    echo "- $CONSTITUTION ($(wc -c < "$CONSTITUTION" | tr -d ' ') bytes) — open the sections for your axis"
  else
    echo "- no constitution.md"
  fi
  if [ -n "$REGISTRY" ]; then
    echo; echo "### $REGISTRY — entries matching changed files"; echo
    printf '%s\n' "${REGISTRY_HITS:-none}"
  fi
  echo
  echo "## Changed files ($NFILES, vs ${BASE_REF:-HEAD}, uncommitted and new files included)"
  echo
  echo '```text'; printf '%s\n' "$NAMES"; [ -n "$SUMMARY" ] && printf '\n%s\n' "$SUMMARY"; echo '```'
  echo
  echo "## Diff"
  echo
  if [ -n "$CUT" ]; then
    echo "Cut at ${MAX_KB} KB of $((DIFF_BYTES / 1024)) KB — for files missing below, run \`git diff $MB -- <file>\` (new files: read them)."
    echo
  fi
  echo '```diff'; printf '%s\n' "$DIFF"; echo '```'
} > "$OUT"

df_gitignore "$OUT"
echo "review packet: $OUT · $FEATURE · $NFILES files · ${SUMMARY:-no changes} · diff $((DIFF_BYTES / 1024)) KB${CUT:+ (cut at ${MAX_KB} KB)} · $(wc -c < "$OUT" | tr -d ' ') bytes"
