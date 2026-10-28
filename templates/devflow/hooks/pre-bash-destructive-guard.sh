#!/usr/bin/env bash
# pre-bash-destructive-guard.sh
# PreToolUse hook for Claude Code: blocks a fixed set of catastrophic/irreversible
# shell commands before execution. Deterministic backstop for the Git Safety
# Protocol already stated in CLAUDE.md — a hook can't be "forgotten" mid-session
# the way a system-prompt rule can.
#
# Scope is intentionally narrow: only commands with no legitimate unattended use
# (root/home wipes, hard resets, protected-branch force-push, hook/signature
# bypass on commit). Anything reversible or context-dependent is left to the
# model's own judgment, per CLAUDE.md.
#
# Triggered by: Bash (Claude Code), run_command (Antigravity CLI)
# Input: host payload, parsed by lib/payload.sh (DF_CMD)
# Block output: lib/emit.sh df_deny → stdout, exit 0
# Allow output: (silent) → exit 0
# Fail-open: missing jq or unparseable input never blocks.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

df_read_input || exit 0
CMD="$DF_CMD"
[[ -z "$CMD" ]] && exit 0

block() {
  df_deny "$1"
  exit 0
}

current_branch() {
  if [[ -n "${DEVFLOW_CURRENT_BRANCH:-}" ]]; then
    printf '%s\n' "$DEVFLOW_CURRENT_BRANCH"
    return
  fi
  git branch --show-current 2>/dev/null || true
}

# ── Normalise ─────────────────────────────────────────────────────────────────
# Strip git global options so `git -C . reset --hard` / `git -c x=y push`
# match the same rules as the plain form; drop quotes around words.
NORM=$(printf '%s' "$CMD" \
  | sed -E 's/"([^"]*)"/\1/g; s/'"'"'([^'"'"']*)'"'"'/\1/g' \
  | sed -E ':a
s/(^|[;&|[:space:]])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+|--no-pager|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|-c[[:space:]]+[^[:space:]]+)/\1git/
ta')
# git -c core.hooksPath=... disables every hook — check on the raw command
HOOKS_PATH_OVERRIDE=false
printf '%s' "$CMD" | grep -qE '\bgit[[:space:]]+(.*[[:space:]])?-c[[:space:]]*core\.hooks[Pp]ath=' && HOOKS_PATH_OVERRIDE=true

# One shell command per line (split on ; && || | &)
split_segments() {
  sed -E 's/(\&\&|\|\||;|\||&)/\
/g'
}
SEGMENTS=$(printf '%s' "$NORM" | split_segments)
# Same, with quoted strings blanked — flags inside commit messages are not flags
BLANKED=$(printf '%s' "$CMD" \
  | sed -E 's/"[^"]*"/Q/g; s/'"'"'[^'"'"']*'"'"'/Q/g' \
  | sed -E ':a
s/(^|[;&|[:space:]])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+|--no-pager|--git-dir=[^[:space:]]+|--work-tree=[^[:space:]]+|-c[[:space:]]+[^[:space:]]+)/\1git/
ta' | split_segments)

# ── rm with recursive + force targeting root, home, cwd, parent, bare glob, .git
rm_is_catastrophic() {
  local seg="$1" w has_r=false has_f=false target_hit=false
  # Word-split without globbing: "*" must stay a literal target
  set -f
  # shellcheck disable=SC2086
  set -- $seg
  set +f
  while [[ $# -gt 0 && "$1" =~ ^(sudo|command|env|nohup|time|[A-Za-z_]+=.*)$ ]]; do shift; done
  [[ "${1:-}" == "rm" ]] || return 1
  shift
  # shellcheck disable=SC2088  # literal ~ targets, matched unexpanded on purpose
  for w in "$@"; do
    case "$w" in
      --recursive) has_r=true ;;
      --force) has_f=true ;;
      --*) ;;
      -*) [[ "$w" == *[rR]* ]] && has_r=true; [[ "$w" == *f* ]] && has_f=true ;;
      /|/\*|/.|'~'|'~/'|'~/*'|\$HOME|\$HOME/|\$HOME/\*|\$\{HOME\}|\$\{HOME\}/|\$\{HOME\}/\*|.|./|./\*|..|../|\*|.git|.git/|*/.git|*/.git/) target_hit=true ;;
    esac
  done
  [[ "$has_r" == true && "$has_f" == true && "$target_hit" == true ]]
}

while IFS= read -r SEG; do
  [[ -z "$SEG" ]] && continue
  if rm_is_catastrophic "$SEG"; then
    block "Blocked: destructive 'rm -rf' targeting root, home, '.', '..', a bare glob, or .git.

DevFlow blocks unattended wipes with no legitimate unattended use case.
If this is genuinely intended, ask the user to run it manually."
  fi
done <<< "$SEGMENTS"

# ── git reset --hard ───────────────────────────────────────────────────────────
if echo "$NORM" | grep -qE '\bgit\s+reset\s+.*--hard\b'; then
  block "Blocked: 'git reset --hard' discards uncommitted work irreversibly.

Ask the user to confirm and run it manually, or use a reversible alternative
(git stash, git reset --soft/--mixed)."
fi

# ── git clean -f(d)(x) ──────────────────────────────────────────────────────────
if echo "$NORM" | grep -qE '\bgit\s+clean\s+(.*\s)?(-[A-Za-z]*f|--force)'; then
  block "Blocked: 'git clean -f' permanently deletes untracked files.

Ask the user to confirm and run it manually. Use 'git clean -n' to preview first."
fi

# ── git checkout/restore discarding all local changes ──────────────────────────
if echo "$NORM" | grep -qE '\bgit\s+(checkout|restore)\s+(--\s+)?\.(/)?(\s|$)' \
  || echo "$NORM" | grep -qE '\bgit\s+restore\s+--staged\s+\.(\s|$)' \
  || echo "$NORM" | grep -qE '\bgit\s+checkout\s+(-f|--force)(\s|$)'; then
  block "Blocked: discards all local changes in the working tree.

Ask the user to confirm and run it manually, or scope the command to specific files."
fi

# ── force-push to a protected branch ────────────────────────────────────────────
# Force = --force / --force-with-lease / -f (also combined, e.g. -uf) / a
# "+refspec". Protected = main/master named anywhere, or a bare push from them.
while IFS= read -r SEG; do
  echo "$SEG" | grep -qE '\bgit\s+push\b' || continue
  REST="${SEG#*git push}"
  FORCE=false
  echo "$REST" | grep -qE '(^|\s)(--force|--force-with-lease(=\S*)?|-[A-Za-z]*f[A-Za-z]*)(\s|$)' && FORCE=true
  echo "$REST" | grep -qE '(^|\s)\+\S+' && FORCE=true
  [[ "$FORCE" == true ]] || continue
  TARGET_BRANCH="$(echo "$REST" | grep -oE '(^|[[:space:]+:])(main|master)([[:space:]]|$)' | head -1 || true)"
  POSITIONAL="$(echo "$REST" | awk '{for(i=1;i<=NF;i++) if($i !~ /^-/) printf "%s ", $i}')"
  POS_COUNT="$(echo "$POSITIONAL" | wc -w | tr -d ' ')"
  if [[ -n "$TARGET_BRANCH" ]] || { [[ "$POS_COUNT" -le 1 ]] && [[ "$(current_branch)" =~ ^(main|master)$ ]]; }; then
    block "Blocked: force-push to a protected branch (main/master).

Per CLAUDE.md Git Safety Protocol: never force-push to main/master without
explicit user confirmation. Ask the user to confirm and run it manually."
  fi
done <<< "$SEGMENTS"

# ── hook/signature bypass on commit ─────────────────────────────────────────────
# --no-verify / -n (alone or combined, e.g. -nm / -an), --no-gpg-sign,
# -c commit.gpgsign=false, -c core.hooksPath=...
COMMIT_BYPASS=false
while IFS= read -r SEG; do
  echo "$SEG" | grep -qE '\bgit\s+commit\b' || continue
  ARGS="${SEG#*git commit}"
  # Unquoted message word after -m (e.g. -m wip) is not a flag either
  ARGS=$(echo "$ARGS" | sed -E 's/(-[A-Za-z]*m|--message)(=|[[:space:]]+)[^-[:space:]][^[:space:]]*/\1/g')
  echo "$ARGS" | grep -qE '(^|\s)(--no-verify|--no-gpg-sign)\b' && COMMIT_BYPASS=true
  echo "$ARGS" | grep -qE '(^|\s)-[A-Za-z]*n[A-Za-z]*(\s|$)' && COMMIT_BYPASS=true
done <<< "$BLANKED"
printf '%s' "$CMD" | grep -qE '\bgit\b.*-c\s*commit\.gpgsign=false.*\bcommit\b' && COMMIT_BYPASS=true
if [[ "$HOOKS_PATH_OVERRIDE" == true ]] && printf '%s' "$CMD" | grep -qE '\bcommit\b|\bpush\b|\bmerge\b|\brebase\b'; then
  COMMIT_BYPASS=true
fi
if [[ "$COMMIT_BYPASS" == true ]]; then
  block "Blocked: commit hook/signature bypass (--no-verify / -n / --no-gpg-sign / gpgsign=false / core.hooksPath override).

Per CLAUDE.md Git Safety Protocol: never skip hooks or bypass signing unless
the user explicitly asked for it. Ask the user to confirm and run it manually."
fi

exit 0
