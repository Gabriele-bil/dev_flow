#!/usr/bin/env bash
# verify-stamp.sh — run each verification once per state of the code, on both
# hosts. A passing run is stamped with the hash of the working tree (tracked +
# untracked files, minus devflow/ and .devflow-* runtime files); the same check
# on the same tree is skipped instead of re-run by the next pipeline step.
#
# Usage (from the project root):
#   verify-stamp.sh run <name> [--cwd DIR] [--log FILE] [--force] -- <command> [args...]
#       fresh pass on this tree → prints "fresh … skipped", exit 0
#       otherwise runs the command (full output → log), prints one result line
#       (+ decisive lines on failure), stamps it, exits with the command's code
#   verify-stamp.sh check [name]   exit 0 when <name> passed on the current tree ('test*':
#                                  every stamp starting with test, at least one); no
#                                  name: a lint/analyze stamp is on this tree and every
#                                  stamp on this tree passed (used by the Stop hook)
#   verify-stamp.sh show           one line per stamped check (fresh/stale, result, counts)
#   verify-stamp.sh tree           current tree hash
#
# <name>: format | lint | analyze | codegen | test | e2e | build, optionally
# :<scope> for a subset (test:auth — never reused as the full "test") and
# @<app> in a monorepo (analyze@web). Default log: .devflow-verify/<name>.log
# Exit 64: usage error. Not a git repository → checks always run, never stamped.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/lib/payload.sh
. "$SCRIPT_DIR/../hooks/lib/payload.sh"

DF_WORKSPACE="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$DF_WORKSPACE" || exit 1
STAMP_FILE="${DEVFLOW_VERIFY_FILE:-.devflow-verify.json}"
LOG_DIR=".devflow-verify"
NAME_RE='^(format|lint|analyze|codegen|test|e2e|build)(:[a-z0-9_-]+)?(@[A-Za-z0-9_.-]+)?$'
HAS_JQ=""; command -v jq >/dev/null 2>&1 && HAS_JQ=1

usage() { printf 'verify-stamp: %s\n' "$1" >&2; exit 64; }

# tree_hash — hash of the working tree through a throwaway index (the real
# index and the working tree are never touched).
tree_hash() {
  git rev-parse --git-dir >/dev/null 2>&1 || return 1
  local idx real
  idx=$(mktemp "${TMPDIR:-/tmp}/devflow-index.XXXXXX") || return 1
  real=$(git rev-parse --git-path index)
  # cp -p keeps the index mtime, so git re-hashes racily clean entries
  [ -f "$real" ] && cp -p "$real" "$idx" || rm -f "$idx"
  GIT_INDEX_FILE="$idx" git add -A -- . ':(exclude)devflow' ':(exclude).devflow-*' >/dev/null 2>&1 \
    && GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null
  local rc=$?
  rm -f "$idx"
  return $rc
}

# counts <log> — "N passed · N failed · N skipped" from common test runners.
counts() {
  local tail_out p f s line
  tail_out=$(tail -n 60 "$1" 2>/dev/null)
  line=$(printf '%s\n' "$tail_out" | grep -E '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: (All tests passed|Some tests failed)' | tail -1)
  if [ -n "$line" ]; then  # flutter test
    p=$(printf '%s' "$line" | sed -E 's/.*\+([0-9]+).*/\1/')
    f=$(printf '%s' "$line" | grep -oE ' -[0-9]+' | tr -dc '0-9')
    s=$(printf '%s' "$line" | grep -oE ' ~[0-9]+' | tr -dc '0-9')
  else
    line=$(printf '%s\n' "$tail_out" | grep -E '[0-9]+ (passed|failed)' | grep -iE 'test|passed|failed' | tail -1)
    [ -n "$line" ] || return 0
    p=$(printf '%s' "$line" | grep -oE '[0-9]+ passed' | tail -1 | tr -dc '0-9')
    f=$(printf '%s' "$line" | grep -oE '[0-9]+ failed' | tail -1 | tr -dc '0-9')
    s=$(printf '%s' "$line" | grep -oE '[0-9]+ (skipped|pending|todo)' | tail -1 | tr -dc '0-9')
  fi
  printf '%s passed · %s failed · %s skipped' "${p:-0}" "${f:-0}" "${s:-0}"
}

stamp_get() { [ -n "$HAS_JQ" ] && [ -s "$STAMP_FILE" ] && jq -r --arg n "$1" ".checks[\$n].$2 // empty" "$STAMP_FILE" 2>/dev/null; }

ago() {
  local at now_s
  at=$(jq -rn --arg t "$1" '$t | fromdateiso8601? // empty' 2>/dev/null)
  [ -n "$at" ] || return 0
  now_s=$(date -u +%s)
  if [ $((now_s - at)) -lt 120 ]; then echo "$((now_s - at))s ago"; else echo "$(((now_s - at) / 60))m ago"; fi
}

cmd_run() {
  local name="$1" cwd="." log="" force=""
  shift || usage "run <name> -- <command>"
  printf '%s' "$name" | grep -qE "$NAME_RE" || usage "invalid check name '$name' — use format|lint|analyze|codegen|test|e2e|build, plus :<scope> for a subset and @<app> in a monorepo"
  while [ $# -gt 0 ]; do
    case "$1" in
      --cwd) cwd="$2"; shift 2 ;;
      --log) log="$2"; shift 2 ;;
      --force) force=1; shift ;;
      --) shift; break ;;
      *) usage "unknown option '$1' (the command goes after --)" ;;
    esac
  done
  [ $# -gt 0 ] || usage "missing command after --"
  [ -d "$cwd" ] || usage "--cwd $cwd: no such directory"
  [ -n "$log" ] || log="$LOG_DIR/$(printf '%s' "$name" | tr ':@' '__').log"
  mkdir -p "$(dirname "$log")"

  # .gitignore first: editing it after stamping would make the stamp stale
  [ -n "$HAS_JQ" ] && df_gitignore "$STAMP_FILE" "$LOG_DIR/"
  local tree
  tree=$(tree_hash)
  if [ -z "$force" ] && [ -n "$tree" ] && [ "$(stamp_get "$name" status)" = pass ] \
     && [ "$(stamp_get "$name" tree)" = "$tree" ] && [ "$(stamp_get "$name" cwd)" = "$cwd" ]; then
    local c; c=$(stamp_get "$name" counts)
    echo "✓ $name: fresh — passed $(ago "$(stamp_get "$name" at)") on this tree${c:+ ($c)}, skipped"
    return 0
  fi

  local start=$SECONDS rc secs c status
  ( cd "$cwd" && "$@" ) > "$log" 2>&1
  rc=$?
  secs=$((SECONDS - start))
  case "$name" in test*|e2e*) c=$(counts "$log") ;; *) c="" ;; esac
  if [ $rc -eq 0 ]; then status=pass; else status=fail; fi

  if [ -n "$HAS_JQ" ]; then
    tree=$(tree_hash)  # after the run: formatters and codegen change files
    df_json_update "$STAMP_FILE" '.checks[$n] = {status: $s, exit: $rc, tree: $t, cwd: $cwd, cmd: $cmd, at: $at, secs: $secs, counts: $c, log: $log}' \
      --arg n "$name" --arg s "$status" --argjson rc "$rc" --arg t "$tree" --arg cwd "$cwd" --arg cmd "$*" \
      --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson secs "$secs" --arg c "$c" --arg log "$log"
  fi

  if [ $rc -eq 0 ]; then
    echo "✓ $name: pass (${secs}s)${c:+ · $c} · log: $log"
  else
    echo "✗ $name: FAIL exit $rc (${secs}s)${c:+ · $c} · log: $log"
    local total; total=$(wc -l < "$log" | tr -d ' ')
    if [ "$total" -le 40 ]; then cat "$log"
    else head -n 15 "$log"; echo "  … $((total - 40)) lines in $log …"; tail -n 25 "$log"; fi
  fi
  return $rc
}

cmd_check() {
  local name="$1" tree
  [ -n "$HAS_JQ" ] && [ -s "$STAMP_FILE" ] || { echo "no stamps"; return 1; }
  tree=$(tree_hash) || { echo "not a git repository"; return 1; }
  case "$name" in
    *\*)
      local prefix="${name%\*}" bad
      bad=$(jq -r --arg p "$prefix" --arg t "$tree" '[(.checks // {}) | to_entries[] | select(.key | startswith($p))]
        | if length == 0 then "none stamped" else map(select(.value.status != "pass" or .value.tree != $t) | .key) | join(", ") end' "$STAMP_FILE")
      if [ -z "$bad" ]; then echo "✓ $name: fresh pass"; return 0; fi
      echo "✗ $name: ${bad} (not a fresh pass)"; return 1
      ;;
  esac
  if [ -n "$name" ]; then
    if [ "$(stamp_get "$name" status)" = pass ] && [ "$(stamp_get "$name" tree)" = "$tree" ]; then
      echo "✓ $name: fresh pass"; return 0
    fi
    echo "✗ $name: $( [ -z "$(stamp_get "$name" status)" ] && echo missing || { [ "$(stamp_get "$name" tree)" = "$tree" ] && echo failed || echo stale; })"
    return 1
  fi
  jq -e --arg t "$tree" '[(.checks // {}) | to_entries[] | select(.value.tree == $t)]
    | any(.key | test("^(lint|analyze)")) and all(.value.status == "pass")' "$STAMP_FILE" >/dev/null 2>&1 \
    && { echo "✓ lint/analyze and every other check on this tree passed"; return 0; }
  echo "✗ no passing stamp set for this tree"; return 1
}

cmd_show() {
  [ -n "$HAS_JQ" ] && [ -s "$STAMP_FILE" ] || { echo "no stamps"; return 0; }
  local tree; tree=$(tree_hash)
  jq -r --arg t "$tree" '.checks | to_entries[] |
    "\(if .value.status == "pass" then "✓" else "✗" end) \(.key): \(.value.status) · \(if .value.tree == $t then "fresh" else "stale" end)\(if (.value.counts // "") != "" then " · " + .value.counts else "" end) · \(.value.at)"' "$STAMP_FILE"
}

case "$1" in
  run) shift; cmd_run "$@" ;;
  check) cmd_check "$2" ;;
  show) cmd_show ;;
  tree) tree_hash || exit 1 ;;
  ""|-h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0" ;;
  *) usage "unknown command '$1' (see --help)" ;;
esac
