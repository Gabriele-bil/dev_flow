#!/bin/bash
# stop-debug-check.sh — Stop hook: scan modified files for debug output statements.
# Reads stdin (passthrough), warns via stderr if debug prints are found, echoes stdin to stdout.

# Read stdin for passthrough
RAW=$(cat)

WARNINGS=""

# Gather modified files from git (staged + unstaged), deduplicated
MODIFIED_FILES=$(
  {
    git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
  } | sort -u
) || true

# Bail early if no modified files
if [ -z "$MODIFIED_FILES" ]; then
  printf '%s' "$RAW"
  exit 0
fi

# Determine active adapter from devflow/config.md in CWD
ADAPTER=""
CONFIG_FILE="devflow/config.md"
if [ -f "$CONFIG_FILE" ]; then
  ADAPTER=$(grep -i '\*\*Adapter:\*\*' "$CONFIG_FILE" 2>/dev/null | sed 's/.*\*\*Adapter:\*\*[[:space:]]*//' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | head -1) || true
fi

# Decide which file types to scan
SCAN_DART=0
SCAN_TS=0

case "$ADAPTER" in
  flutter)
    SCAN_DART=1
    ;;
  angular)
    SCAN_TS=1
    ;;
  *)
    # Unknown adapter: detect by presence of relevant file types among modified files
    if echo "$MODIFIED_FILES" | grep -q '\.dart$' 2>/dev/null; then
      SCAN_DART=1
    fi
    if echo "$MODIFIED_FILES" | grep -q '\.ts$' 2>/dev/null; then
      SCAN_TS=1
    fi
    # If still nothing detected, scan both
    if [ "$SCAN_DART" -eq 0 ] && [ "$SCAN_TS" -eq 0 ]; then
      SCAN_DART=1
      SCAN_TS=1
    fi
    ;;
esac

# Helper: check a list of files (up to 10) for a pattern
# Usage: check_files <pattern> <extension> <files>
check_files() {
  local pattern="$1"
  local ext="$2"
  local result=""
  local count=0

  while IFS= read -r filepath; do
    # Skip files inside devflow/ (plugin internals)
    case "$filepath" in
      devflow/*) continue ;;
    esac

    # Only process files matching the target extension
    case "$filepath" in
      *"$ext") : ;;
      *) continue ;;
    esac

    # Only scan files that actually exist
    [ -f "$filepath" ] || continue

    count=$((count + 1))
    if [ "$count" -gt 10 ]; then
      break
    fi

    local matches
    matches=$(grep -n "$pattern" "$filepath" 2>/dev/null) || true
    if [ -n "$matches" ]; then
      result="${result}  ${filepath}:"$'\n'"$(echo "$matches" | sed 's/^/    /')"$'\n'
    fi
  done <<< "$MODIFIED_FILES"

  printf '%s' "$result"
}

# Run scans
if [ "$SCAN_DART" -eq 1 ]; then
  DART_HITS=$(check_files 'print(' '.dart')
  if [ -n "$DART_HITS" ]; then
    WARNINGS="${WARNINGS}[Dart] print() calls found:"$'\n'"${DART_HITS}"
  fi
fi

if [ "$SCAN_TS" -eq 1 ]; then
  TS_HITS=$(check_files 'console\.log(' '.ts')
  if [ -n "$TS_HITS" ]; then
    WARNINGS="${WARNINGS}[TypeScript] console.log() calls found:"$'\n'"${TS_HITS}"
  fi
fi

# Emit warning to stderr if any debug output was found
if [ -n "$WARNINGS" ]; then
  printf '\n⚠️  DEBUG OUTPUT DETECTED in modified files:\n%s\nConsider removing debug statements before committing.\n\n' "$WARNINGS" >&2
fi

# Passthrough: always emit raw stdin to stdout unchanged
printf '%s' "$RAW"

exit 0
