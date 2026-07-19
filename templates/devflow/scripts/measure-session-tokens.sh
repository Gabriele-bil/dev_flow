#!/bin/bash
# measure-session-tokens.sh — aggregate token usage + tool-call mix from Claude Code
# session transcripts (JSONL under ~/.claude/projects/<encoded-project>/).
# A/B evidence for instruction-level changes — see docs/tokless-gap-analysis.md
# appendix: compare input tokens + explore-call counts with/without a SKILL.md change.
#
# Usage:
#   bash measure-session-tokens.sh <transcript.jsonl> [more.jsonl ...]
#   bash measure-session-tokens.sh --project <consumer-project-dir>
#
# Output: one line per transcript + TOTAL. Columns:
#   in/out        — direct input/output tokens (uncached)
#   cache r/w     — prompt-cache read / creation tokens
#   tools         — total tool_use blocks
#   explore       — Read+Grep+Glob calls (direct proxy for index-first effect)
#   bash          — Bash calls
#   semantic      — mcp__* calls (index/MCP queries)

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

FILES=()
if [ "${1:-}" = "--project" ]; then
  [ -n "${2:-}" ] || { echo "usage: measure-session-tokens.sh --project <dir>" >&2; exit 1; }
  ENC=$(printf '%s' "$2" | sed 's/[^a-zA-Z0-9]/-/g')
  PROJ_DIR="$HOME/.claude/projects/$ENC"
  [ -d "$PROJ_DIR" ] || { echo "no transcripts: $PROJ_DIR" >&2; exit 1; }
  while IFS= read -r f; do FILES+=("$f"); done < <(ls "$PROJ_DIR"/*.jsonl 2>/dev/null)
else
  FILES=("$@")
fi
[ "${#FILES[@]}" -gt 0 ] || { echo "no transcript files given" >&2; exit 1; }

SUMMARIES=""
printf '%-28s %10s %9s %11s %11s %6s %8s %6s %9s\n' \
  "transcript" "in" "out" "cache-r" "cache-w" "tools" "explore" "bash" "semantic"

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "skip (not a file): $f" >&2; continue; }
  S=$(jq -s '
    [ .[] | select(.type=="assistant") | .message.usage // {} ] as $u |
    [ .[] | select(.type=="assistant")
      | (.message.content // [])[]? | select(.type=="tool_use") | .name ] as $t |
    { input:      ([$u[].input_tokens // 0] | add // 0),
      output:     ([$u[].output_tokens // 0] | add // 0),
      cache_read: ([$u[].cache_read_input_tokens // 0] | add // 0),
      cache_write:([$u[].cache_creation_input_tokens // 0] | add // 0),
      tools:      ($t | length),
      explore:    ([$t[] | select(. == "Read" or . == "Grep" or . == "Glob")] | length),
      bash:       ([$t[] | select(. == "Bash")] | length),
      semantic:   ([$t[] | select(startswith("mcp__"))] | length) }
  ' "$f" 2>/dev/null) || { echo "skip (bad JSONL): $f" >&2; continue; }
  SUMMARIES="$SUMMARIES$S"
  printf '%-28s %10s %9s %11s %11s %6s %8s %6s %9s\n' \
    "$(basename "$f" .jsonl | head -c 28)" \
    "$(jq -r '.input' <<<"$S")" "$(jq -r '.output' <<<"$S")" \
    "$(jq -r '.cache_read' <<<"$S")" "$(jq -r '.cache_write' <<<"$S")" \
    "$(jq -r '.tools' <<<"$S")" "$(jq -r '.explore' <<<"$S")" \
    "$(jq -r '.bash' <<<"$S")" "$(jq -r '.semantic' <<<"$S")"
done

[ -n "$SUMMARIES" ] || { echo "no readable transcripts" >&2; exit 1; }

T=$(jq -s '
  { input: ([.[].input]|add), output: ([.[].output]|add),
    cache_read: ([.[].cache_read]|add), cache_write: ([.[].cache_write]|add),
    tools: ([.[].tools]|add), explore: ([.[].explore]|add),
    bash: ([.[].bash]|add), semantic: ([.[].semantic]|add) }' <<<"$SUMMARIES")
printf '%-28s %10s %9s %11s %11s %6s %8s %6s %9s\n' \
  "TOTAL" \
  "$(jq -r '.input' <<<"$T")" "$(jq -r '.output' <<<"$T")" \
  "$(jq -r '.cache_read' <<<"$T")" "$(jq -r '.cache_write' <<<"$T")" \
  "$(jq -r '.tools' <<<"$T")" "$(jq -r '.explore' <<<"$T")" \
  "$(jq -r '.bash' <<<"$T")" "$(jq -r '.semantic' <<<"$T")"
