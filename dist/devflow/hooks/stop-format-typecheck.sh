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

CONFIG_FILE="devflow/config.md"

# Monorepo mode: devflow/config.md declares a `## Apps` table.
IS_MONOREPO=""
if [[ -f "$CONFIG_FILE" ]] && grep -q '^## Apps' "$CONFIG_FILE"; then
  IS_MONOREPO=1
fi

# Detect adapter from devflow/config.md (single-app only — monorepo resolves
# one adapter per app below instead of a single repo-wide adapter).
ADAPTER=""
if [[ -z "$IS_MONOREPO" ]]; then
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
  fi

  if [[ -z "$ADAPTER" ]]; then
    # Distinguish Next.js from Angular before falling back to .ts detection.
    # Check for next.config.* in project root (most reliable signal).
    if compgen -G "next.config.*" > /dev/null 2>&1; then
      ADAPTER="nextjs"
    elif [[ -f "package.json" ]] && grep -q '"next"' package.json 2>/dev/null; then
      ADAPTER="nextjs"
    fi
  fi

  if [[ -z "$ADAPTER" ]]; then
    for f in "${CHANGED_FILES[@]}"; do
      if [[ "$f" == *.ts ]]; then
        ADAPTER="angular"
        break
      fi
    done
  fi
fi

# Monorepo: parse the `## Apps` table (App | Path | Adapter | Adapter root)
# into parallel arrays. Rows are matched against changed-file paths below by
# longest-prefix so each app's checks run scoped to its own directory.
APP_NAMES=()
APP_PATHS=()
APP_ADAPTERS=()

if [[ -n "$IS_MONOREPO" ]]; then
  while IFS='|' read -r _ col1 col2 col3 _; do
    name=$(echo "$col1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    path=$(echo "$col2" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    adapter=$(echo "$col3" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
    [[ -z "$name" || "$name" == "App" || "$name" == ---* ]] && continue
    APP_NAMES+=("$name")
    APP_PATHS+=("$path")
    APP_ADAPTERS+=("$adapter")
  done < <(awk '/^## Apps/{f=1;next} /^## /{f=0} f && /^\|/' "$CONFIG_FILE")
fi

# Helper: run a command, emit result on stderr.
# Output is capped (head+tail, MAX_OUTPUT_CHARS) to avoid dumping unbounded
# lint/typecheck output into every Stop event — mirrors the cap applied to
# regular Bash tool output in post-bash-output-filter.sh.
MAX_OUTPUT_CHARS="${DEVFLOW_TYPECHECK_MAX_CHARS:-2500}"
HEAD_LINES="${DEVFLOW_TYPECHECK_HEAD:-20}"
TAIL_LINES="${DEVFLOW_TYPECHECK_TAIL:-15}"

run_cmd() {
  local label="$1"
  shift
  local output
  output=$("$@" 2>&1)
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf '✓ %s: ok\n' "$label" >&2
  else
    local chars=${#output}
    if [[ "$chars" -gt "$MAX_OUTPUT_CHARS" ]]; then
      local total
      total=$(printf '%s\n' "$output" | wc -l | tr -d ' ')
      output=$(printf '%s\n' "$output" | awk -v head="$HEAD_LINES" -v tail="$TAIL_LINES" -v total="$total" '
        NR <= head || NR > total - tail { print; next }
        { skipped++ }
        END { }
      ')
      output="${output}
  … [output truncated, ${chars} chars raw] …"
    fi
    printf '⚠ %s issues:\n%s\n' "$label" "$output" >&2
  fi
  return 0
}

# Run format+analyze for one adapter, scoped to $cwd, over files in the
# global GROUP_FILES array (caller sets it before calling). $cwd is "."
# in single-app mode, so this is a no-op scoping change there.
run_checks_for_adapter() {
  local adapter="$1"
  local cwd="$2"

  (
    cd "$cwd" || exit 0

    case "$adapter" in
      flutter)
        HAS_DART=0
        for f in "${GROUP_FILES[@]}"; do
          if [[ "$f" == *.dart ]]; then
            HAS_DART=1
            break
          fi
        done
        [[ $HAS_DART -eq 0 ]] && exit 0

        if ! command -v dart &>/dev/null; then
          printf '⚠ dart not found in PATH, skipping format+analyze\n' >&2
          exit 0
        fi

        run_cmd "dart format" dart format . || true
        run_cmd "dart analyze" timeout 60 dart analyze || true
        ;;

      nextjs)
        HAS_TS=0
        for f in "${GROUP_FILES[@]}"; do
          if [[ "$f" == *.ts || "$f" == *.tsx ]]; then
            HAS_TS=1
            break
          fi
        done
        [[ $HAS_TS -eq 0 ]] && exit 0

        if ! command -v pnpm &>/dev/null; then
          printf '⚠ pnpm not found in PATH, skipping lint+typecheck\n' >&2
          exit 0
        fi

        run_cmd "pnpm lint" pnpm lint || true
        run_cmd "pnpm exec tsc --noEmit" timeout 60 pnpm exec tsc --noEmit || true
        ;;

      angular)
        HAS_TS=0
        for f in "${GROUP_FILES[@]}"; do
          if [[ "$f" == *.ts ]]; then
            HAS_TS=1
            break
          fi
        done
        [[ $HAS_TS -eq 0 ]] && exit 0

        if ! command -v pnpm &>/dev/null; then
          printf '⚠ pnpm not found in PATH, skipping lint+typecheck\n' >&2
          exit 0
        fi

        run_cmd "pnpm run lint" pnpm run lint || true
        run_cmd "pnpm exec tsc --noEmit" timeout 60 pnpm exec tsc --noEmit || true
        ;;

      *)
        printf '⚠ devflow: adapter "%s" not recognized or not detected, skipping format+analyze\n' "$adapter" >&2
        ;;
    esac
  )
}

if [[ -n "$IS_MONOREPO" ]]; then
  for i in "${!APP_NAMES[@]}"; do
    app_path="${APP_PATHS[$i]}"
    app_adapter="${APP_ADAPTERS[$i]}"
    [[ -z "$app_path" ]] && continue

    GROUP_FILES=()
    for f in "${CHANGED_FILES[@]}"; do
      case "$f" in
        "$app_path"/*) GROUP_FILES+=("$f") ;;
      esac
    done
    [[ ${#GROUP_FILES[@]} -eq 0 ]] && continue

    run_checks_for_adapter "$app_adapter" "$app_path"
  done
else
  GROUP_FILES=("${CHANGED_FILES[@]}")
  run_checks_for_adapter "$ADAPTER" "."
fi

# Passthrough
printf '%s' "$RAW"
exit 0
