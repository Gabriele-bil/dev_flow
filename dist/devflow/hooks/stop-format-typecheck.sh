#!/bin/bash
# Stop hook: runs format+analyze on files accumulated in .devflow-changed-files.tmp
# Passthrough: reads stdin and writes it back to stdout unchanged.

RAW=$(cat)  # passthrough — must be re-emitted at the end

TMP_FILE=".devflow-changed-files.tmp"

# If no accumulated files, passthrough and exit
if [[ ! -f "$TMP_FILE" ]] || [[ ! -s "$TMP_FILE" ]]; then
  printf '%s' "$RAW"
  exit 0
fi

# Read changed files into array
CHANGED_FILES=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -n "$line" ]] && CHANGED_FILES+=("$line")
done < "$TMP_FILE"

# Reset tmp file immediately for the next response
rm -f "$TMP_FILE"

# Detect adapter from devflow/config.md
ADAPTER=""
CONFIG_FILE="devflow/config.md"

if [[ -f "$CONFIG_FILE" ]]; then
  ADAPTER=$(grep -i '^\*\*Adapter:\*\*' "$CONFIG_FILE" | sed 's/\*\*Adapter:\*\*[[:space:]]*//' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
fi

# Auto-detect if adapter not found in config
if [[ -z "$ADAPTER" ]]; then
  for f in "${CHANGED_FILES[@]}"; do
    if [[ "$f" == *.dart ]]; then
      ADAPTER="flutter"
      break
    fi
  done
  if [[ -z "$ADAPTER" ]]; then
    for f in "${CHANGED_FILES[@]}"; do
      if [[ "$f" == *.ts ]]; then
        ADAPTER="angular"
        break
      fi
    done
  fi
fi

# Helper: run a command, emit result on stderr
run_cmd() {
  local label="$1"
  shift
  local output
  output=$("$@" 2>&1)
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf '✓ %s: ok\n' "$label" >&2
  else
    printf '⚠ %s issues:\n%s\n' "$label" "$output" >&2
  fi
  return 0
}

case "$ADAPTER" in
  flutter)
    # Filter for .dart files
    HAS_DART=0
    for f in "${CHANGED_FILES[@]}"; do
      if [[ "$f" == *.dart ]]; then
        HAS_DART=1
        break
      fi
    done

    if [[ $HAS_DART -eq 0 ]]; then
      printf '%s' "$RAW"
      exit 0
    fi

    if ! command -v dart &>/dev/null; then
      printf '⚠ dart not found in PATH, skipping format+analyze\n' >&2
      printf '%s' "$RAW"
      exit 0
    fi

    run_cmd "dart format" dart format . || true
    run_cmd "dart analyze" timeout 60 dart analyze || true
    ;;

  angular)
    # Filter for .ts files
    HAS_TS=0
    for f in "${CHANGED_FILES[@]}"; do
      if [[ "$f" == *.ts ]]; then
        HAS_TS=1
        break
      fi
    done

    if [[ $HAS_TS -eq 0 ]]; then
      printf '%s' "$RAW"
      exit 0
    fi

    if ! command -v pnpm &>/dev/null; then
      printf '⚠ pnpm not found in PATH, skipping lint+typecheck\n' >&2
      printf '%s' "$RAW"
      exit 0
    fi

    run_cmd "pnpm run lint" pnpm run lint || true
    run_cmd "pnpm exec tsc --noEmit" timeout 60 pnpm exec tsc --noEmit || true
    ;;

  *)
    # Unknown or undetected adapter — skip silently
    printf '⚠ devflow: adapter "%s" not recognized or not detected, skipping format+analyze\n' "$ADAPTER" >&2
    ;;
esac

# Passthrough
printf '%s' "$RAW"
exit 0
