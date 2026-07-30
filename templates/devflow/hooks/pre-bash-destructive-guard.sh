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
# Triggered by: Bash tool
# Input (stdin): JSON { "session_id": "...", "tool_use": { "id": "...", "name": "Bash", "input": { "command": "..." } } }
# Block output:  { "decision": "block", "reason": "..." }  → stdout, exit 0
# Allow output:  (silent) → exit 0

set -euo pipefail

# Require jq — if not available, allow silently (never block for missing tooling)
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT="$(cat 2>/dev/null || true)"
[[ -z "$INPUT" ]] && exit 0

CMD="$(echo "$INPUT" | jq -r '.tool_use.input.command // empty' 2>/dev/null || true)"
[[ -z "$CMD" ]] || [[ "$CMD" == "null" ]] && exit 0

block() {
  local reason="$1"
  printf '%s' "$(jq -n --arg reason "$reason" '{"decision":"block","reason":$reason}')"
  exit 0
}

current_branch() {
  git branch --show-current 2>/dev/null || true
}

# ── rm -rf / -fr targeting root, home, or repo-wide globs ─────────────────────
HAS_RF_FLAGS=false
if echo "$CMD" | grep -qE '\brm\s+[^|;&]*-[A-Za-z]*r[A-Za-z]*f[A-Za-z]*\b' \
  || echo "$CMD" | grep -qE '\brm\s+[^|;&]*-[A-Za-z]*f[A-Za-z]*r[A-Za-z]*\b' \
  || echo "$CMD" | grep -qE '\brm\s+[^|;&]*--recursive\b[^|;&]*--force\b' \
  || echo "$CMD" | grep -qE '\brm\s+[^|;&]*--force\b[^|;&]*--recursive\b'; then
  HAS_RF_FLAGS=true
fi

if [[ "$HAS_RF_FLAGS" == true ]]; then
  if echo "$CMD" | grep -qE '\brm\s+[^|;&]*\s(/|~|~/\*?|\.|\.\.|\*)\s*($|[|;&])' \
    || echo "$CMD" | grep -qE '\brm\s+[^|;&]*\.git(/|\s|$)'; then
    block "Blocked: destructive 'rm -rf' targeting root, home, '.', '..', a bare glob, or .git.

DevFlow blocks unattended wipes with no legitimate unattended use case.
If this is genuinely intended, ask the user to run it manually."
  fi
fi

# ── git reset --hard ───────────────────────────────────────────────────────────
if echo "$CMD" | grep -qE '\bgit\s+reset\s+.*--hard\b'; then
  block "Blocked: 'git reset --hard' discards uncommitted work irreversibly.

Ask the user to confirm and run it manually, or use a reversible alternative
(git stash, git reset --soft/--mixed)."
fi

# ── git clean -f(d)(x) ──────────────────────────────────────────────────────────
if echo "$CMD" | grep -qE '\bgit\s+clean\s+.*-[A-Za-z]*f'; then
  block "Blocked: 'git clean -f' permanently deletes untracked files.

Ask the user to confirm and run it manually. Use 'git clean -n' to preview first."
fi

# ── git checkout/restore discarding all local changes ──────────────────────────
if echo "$CMD" | grep -qE '\bgit\s+(checkout|restore)\s+(--\s+)?\.(\s|$)' \
  || echo "$CMD" | grep -qE '\bgit\s+restore\s+--staged\s+\.(\s|$)'; then
  block "Blocked: discards all local changes in the working tree.

Ask the user to confirm and run it manually, or scope the command to specific files."
fi

# ── force-push to a protected branch ────────────────────────────────────────────
if echo "$CMD" | grep -qE '\bgit\s+push\b.*(--force\b|--force-with-lease\b|\s-f\b)'; then
  TARGET_BRANCH="$(echo "$CMD" | grep -oE '\b(main|master)\b' | head -1 || true)"
  # Words left after "git push", minus the force flags — anything beyond a bare
  # remote name means an explicit (non-main/master) refspec was given.
  REST="${CMD#*git push}"
  REST="${REST//--force-with-lease/ }"
  REST="${REST//--force/ }"
  REST="$(echo "$REST" | awk '{for(i=1;i<=NF;i++) if($i!="-f") printf "%s ", $i}')"
  REST_WORDS="$(echo "$REST" | wc -w | tr -d ' ')"
  if [[ -n "$TARGET_BRANCH" ]] || { [[ "$REST_WORDS" -le 1 ]] && [[ "$(current_branch)" =~ ^(main|master)$ ]]; }; then
    block "Blocked: force-push to a protected branch (main/master).

Per CLAUDE.md Git Safety Protocol: never force-push to main/master without
explicit user confirmation. Ask the user to confirm and run it manually."
  fi
fi

# ── hook/signature bypass on commit ─────────────────────────────────────────────
if echo "$CMD" | grep -qE '\bgit\s+commit\b' \
  && echo "$CMD" | grep -qE -- '--no-verify\b|--no-gpg-sign\b|-c\s+commit\.gpgsign=false'; then
  block "Blocked: commit hook/signature bypass (--no-verify / --no-gpg-sign / gpgsign=false).

Per CLAUDE.md Git Safety Protocol: never skip hooks or bypass signing unless
the user explicitly asked for it. Ask the user to confirm and run it manually."
fi

exit 0
