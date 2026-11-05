#!/usr/bin/env bash
# pre-bash-stamp-guard.sh
# PreToolUse hook: while run mode is armed (.devflow-run.json — devflow.run /
# devflow.auto), deny check commands (test, lint, analyze/typecheck, format,
# e2e, build) launched outside scripts/verify-stamp.sh.
#
# Why: a raw check dumps its full output into the step's context and is never
# stamped, so the next step re-runs it instead of printing "fresh … skipped".
# Observed on real runs: dozens of raw `pnpm --filter <app> test` per feature.
#
# Scope is intentionally narrow: run mode only (interactive sessions are never
# blocked), Node package managers + common JS tooling + flutter/dart. Anything
# wrapped by verify-stamp.sh, --help/--version, and quoted strings are allowed.
# DEVFLOW_STAMP_GUARD=off disables the hook.
#
# Triggered by: Bash (Claude Code), run_command (Antigravity CLI)
# Input: host payload, parsed by lib/payload.sh (DF_CMD)
# Block output: lib/emit.sh df_deny → stdout, exit 0
# Allow output: (silent) → exit 0
# Fail-open: missing jq or unparseable input never blocks.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

[ "${DEVFLOW_STAMP_GUARD:-on}" = "off" ] && exit 0
df_read_input || exit 0
CMD="$DF_CMD"
[ -z "$CMD" ] && exit 0
[ -f "$DF_WORKSPACE/.devflow-run.json" ] || exit 0
case "$CMD" in *verify-stamp.sh*) exit 0 ;; esac

STAMP="$(cd "$HOOK_DIR/../scripts" 2>/dev/null && pwd)/verify-stamp.sh"

# Quoted strings blanked (a commit message is not a command), then one shell
# command per line (split on ; && || | &)
SEGMENTS=$(printf '%s' "$CMD" \
  | sed -E 's/"[^"]*"/Q/g; s/'"'"'[^'"'"']*'"'"'/Q/g' \
  | sed -E 's/(\&\&|\|\||;|\||&)/\
/g')

SCRIPT_RE='^(test|t|lint|typecheck|type-check|check-types|tsc|analyze|build|format|e2e|(test|lint|e2e|format|typecheck|build):.+)$'

# tool_is_check <tool> <next-word> — JS/Dart tool invocation that runs a check
tool_is_check() {
  case "$1" in
    tsc|eslint|prettier|biome|jest|vitest|cypress) return 0 ;;
    playwright) [ "$2" = "test" ]; return ;;
    ng|nx|turbo) case "$2" in test|lint|build|e2e|run|run-many|affected) return 0 ;; esac; return 1 ;;
    flutter) case "$2" in test|analyze|build) return 0 ;; esac; return 1 ;;
    dart) case "$2" in analyze|format|test) return 0 ;; esac; return 1 ;;
  esac
  return 1
}

# segment_is_check <segment> — package-manager script or direct tool check
segment_is_check() {
  local w tool sub script skip_next=false
  set -f
  # shellcheck disable=SC2086
  set -- $1
  set +f
  while [ $# -gt 0 ] && [[ "$1" =~ ^(sudo|command|env|nohup|time|[A-Za-z_][A-Za-z0-9_]*=.*)$ ]]; do shift; done
  [ $# -gt 0 ] || return 1
  for w in "$@"; do
    case "$w" in --help|-h|--version) return 1 ;; esac
  done
  tool="${1##*/}"; shift
  case "$tool" in
    pnpm|npm|yarn|bun)
      sub="" script=""
      for w in "$@"; do
        if $skip_next; then skip_next=false; continue; fi
        case "$w" in
          --filter|-F|-C|--dir|--prefix|--workspace|--cwd) skip_next=true; continue ;;
          -*) continue ;;
        esac
        if [ -z "$sub" ]; then sub="$w"; continue; fi
        script="$w"; break
      done
      case "$sub" in
        run|run-script) [[ "$script" =~ $SCRIPT_RE ]] ;;
        exec|dlx|x) tool_is_check "$script" "$(next_after "$script" "$@")" ;;
        *) [[ "$sub" =~ $SCRIPT_RE ]] ;;
      esac
      return $?
      ;;
    npx|bunx)
      for w in "$@"; do
        case "$w" in -*) continue ;; esac
        tool_is_check "$w" "$(next_after "$w" "$@")"; return $?
      done
      return 1
      ;;
  esac
  tool_is_check "$tool" "${1:-}"
}

# next_after <word> <args...> — the argument following <word>
next_after() {
  local target="$1" w found=false; shift
  for w in "$@"; do
    if $found; then printf '%s' "$w"; return 0; fi
    [ "$w" = "$target" ] && found=true
  done
}

while IFS= read -r seg; do
  [ -n "${seg// /}" ] || continue
  if segment_is_check "$seg"; then
    df_deny "devflow run mode: checks run through the verification stamp, never raw — bash \"$STAMP\" run <test|lint|analyze|format|e2e|build>[:<scope>][@<app>] [--cwd <dir>] -- <cmd>. A pass is reused by later steps on the same tree; full output stays in .devflow-verify/<name>.log (read decisive lines only). Subset of tests: test:<scope>."
    exit 0
  fi
done <<EOF
$SEGMENTS
EOF
exit 0
