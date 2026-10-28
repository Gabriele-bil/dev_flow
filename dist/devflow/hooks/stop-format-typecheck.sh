#!/bin/bash
# Stop hook: runs format+analyze on files accumulated in .devflow-changed-files.tmp
# Results reach the user as one systemMessage (lib/emit.sh df_notify), only when
# a check reports issues — stderr from a Stop hook is never shown.
# Formatters run on the changed files only, never on the whole project.
# Timeouts use timeout / gtimeout (coreutils) when present, else no limit.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

df_read_input || exit 0

WORKSPACE_ROOT="$DF_WORKSPACE"
TMP_FILE="${DEVFLOW_CHANGED_FILES_TMP:-$WORKSPACE_ROOT/.devflow-changed-files.tmp}"

[[ -f "$TMP_FILE" && -s "$TMP_FILE" ]] || exit 0

# Read changed files into array, as workspace-relative paths (the accumulator
# stores whatever the tool reported — usually absolute)
CHANGED_FILES=()
df_lock "$TMP_FILE" || exit 0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  line="$(df_rel_path "$line")"
  [[ -f "$WORKSPACE_ROOT/$line" ]] && CHANGED_FILES+=("$line")
done < "$TMP_FILE"
# Reset tmp file immediately for the next response
rm -f "$TMP_FILE"
df_unlock "$TMP_FILE"
[[ ${#CHANGED_FILES[@]} -eq 0 ]] && exit 0

# Portable timeout: GNU timeout, Homebrew coreutils gtimeout, else none
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT=(timeout 60)
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT=(gtimeout 60)
else
  TIMEOUT=()
fi

CONFIG_FILE="${DEVFLOW_CONFIG_FILE:-$WORKSPACE_ROOT/devflow/config.md}"

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

# Helper: run a command, print its result on stdout (collected into REPORT).
# Output is capped (head+tail, MAX_OUTPUT_CHARS) to avoid dumping unbounded
# lint/typecheck output into every Stop event — mirrors the cap applied to
# regular Bash tool output in post-bash-output-filter.sh.
MAX_OUTPUT_CHARS="${DEVFLOW_TYPECHECK_MAX_CHARS:-2500}"
HEAD_LINES="${DEVFLOW_TYPECHECK_HEAD:-20}"
TAIL_LINES="${DEVFLOW_TYPECHECK_TAIL:-15}"

# Skip checks the consumer project's own pre-commit hook manager (husky,
# lefthook) already runs — same lint/typecheck work would otherwise run
# twice per commit for no benefit (this hook never blocks either way, it's
# advisory-only, so there's no coverage gap from skipping here).
HOOK_MANAGER_COVERS_LINT=0
HOOK_MANAGER_COVERS_TYPECHECK=0
if [[ -z "${DEVFLOW_FORCE_TYPECHECK:-}" ]]; then
  HOOK_MGR_FILES=()
  [[ -f "$WORKSPACE_ROOT/.husky/pre-commit" ]] && HOOK_MGR_FILES+=("$WORKSPACE_ROOT/.husky/pre-commit")
  [[ -f "$WORKSPACE_ROOT/lefthook.yml" ]] && HOOK_MGR_FILES+=("$WORKSPACE_ROOT/lefthook.yml")
  [[ -f "$WORKSPACE_ROOT/.lefthook.yml" ]] && HOOK_MGR_FILES+=("$WORKSPACE_ROOT/.lefthook.yml")

  for f in "${HOOK_MGR_FILES[@]}"; do
    grep -qE 'lint|format' "$f" 2>/dev/null && HOOK_MANAGER_COVERS_LINT=1
    grep -qE 'tsc|typecheck|analyze' "$f" 2>/dev/null && HOOK_MANAGER_COVERS_TYPECHECK=1
  done
fi

run_cmd() {
  local label="$1"
  shift
  local output
  output=$(${TIMEOUT[@]+"${TIMEOUT[@]}"} "$@" 2>&1)
  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    printf '✓ %s: ok\n' "$label"
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
    printf '⚠ %s issues:\n%s\n' "$label" "$output"
  fi
  return 0
}

# Run format+analyze for one adapter, scoped to $cwd, over files in the
# global GROUP_FILES array (workspace-relative; caller sets it). $cwd is the
# workspace root in single-app mode, the app dir in monorepo mode.
run_checks_for_adapter() {
  local adapter="$1"
  local cwd="$2"

  (
    cd "$cwd" || exit 0
    # Changed files relative to $cwd (formatters take explicit paths)
    REL_FILES=()
    for f in "${GROUP_FILES[@]}"; do
      REL_FILES+=("${WORKSPACE_ROOT}/${f}")
    done

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

        if [[ $HOOK_MANAGER_COVERS_LINT -eq 1 && $HOOK_MANAGER_COVERS_TYPECHECK -eq 1 ]]; then
          printf '⏭ dart format+analyze: already covered by pre-commit hook manager, skipping\n'
          exit 0
        fi

        if ! command -v dart &>/dev/null; then
          printf '⏭ dart not found in PATH, skipping format+analyze\n'
          exit 0
        fi

        if [[ $HOOK_MANAGER_COVERS_LINT -eq 1 ]]; then
          printf '⏭ dart format: already covered by pre-commit hook manager, skipping\n'
        else
          DART_FILES=()
          for f in "${REL_FILES[@]}"; do [[ "$f" == *.dart ]] && DART_FILES+=("$f"); done
          run_cmd "dart format" dart format "${DART_FILES[@]}" || true
        fi
        if [[ $HOOK_MANAGER_COVERS_TYPECHECK -eq 1 ]]; then
          printf '⏭ dart analyze: already covered by pre-commit hook manager, skipping\n'
        else
          run_cmd "dart analyze" dart analyze || true
        fi
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

        if [[ $HOOK_MANAGER_COVERS_LINT -eq 1 && $HOOK_MANAGER_COVERS_TYPECHECK -eq 1 ]]; then
          printf '⏭ pnpm lint+typecheck: already covered by pre-commit hook manager, skipping\n'
          exit 0
        fi

        if ! command -v pnpm &>/dev/null; then
          printf '⏭ pnpm not found in PATH, skipping lint+typecheck\n'
          exit 0
        fi

        if [[ $HOOK_MANAGER_COVERS_LINT -eq 1 ]]; then
          printf '⏭ pnpm lint: already covered by pre-commit hook manager, skipping\n'
        else
          run_cmd "pnpm lint" pnpm lint || true
        fi
        if [[ $HOOK_MANAGER_COVERS_TYPECHECK -eq 1 ]]; then
          printf '⏭ pnpm exec tsc --noEmit: already covered by pre-commit hook manager, skipping\n'
        else
          run_cmd "pnpm exec tsc --noEmit" pnpm exec tsc --noEmit || true
        fi
        ;;

      angular|nestjs)
        HAS_TS=0
        for f in "${GROUP_FILES[@]}"; do
          if [[ "$f" == *.ts ]]; then
            HAS_TS=1
            break
          fi
        done
        [[ $HAS_TS -eq 0 ]] && exit 0

        if [[ $HOOK_MANAGER_COVERS_LINT -eq 1 && $HOOK_MANAGER_COVERS_TYPECHECK -eq 1 ]]; then
          printf '⏭ pnpm run lint+typecheck: already covered by pre-commit hook manager, skipping\n'
          exit 0
        fi

        if ! command -v pnpm &>/dev/null; then
          printf '⏭ pnpm not found in PATH, skipping lint+typecheck\n'
          exit 0
        fi

        if [[ $HOOK_MANAGER_COVERS_LINT -eq 1 ]]; then
          printf '⏭ pnpm run lint: already covered by pre-commit hook manager, skipping\n'
        else
          run_cmd "pnpm run lint" pnpm run lint || true
        fi
        if [[ $HOOK_MANAGER_COVERS_TYPECHECK -eq 1 ]]; then
          printf '⏭ pnpm exec tsc --noEmit: already covered by pre-commit hook manager, skipping\n'
        else
          run_cmd "pnpm exec tsc --noEmit" pnpm exec tsc --noEmit || true
        fi
        ;;

      *)
        printf '⏭ devflow: adapter "%s" not recognized or not detected, skipping format+analyze\n' "$adapter"
        ;;
    esac
  )
}

REPORT=""
if [[ -n "$IS_MONOREPO" ]]; then
  for i in "${!APP_NAMES[@]}"; do
    app_path="${APP_PATHS[$i]%/}"
    app_path="${app_path#./}"
    app_adapter="${APP_ADAPTERS[$i]}"
    [[ -z "$app_path" ]] && continue

    GROUP_FILES=()
    for f in "${CHANGED_FILES[@]}"; do
      case "$f" in
        "$app_path"/*) GROUP_FILES+=("$f") ;;
      esac
    done
    [[ ${#GROUP_FILES[@]} -eq 0 ]] && continue

    APP_REPORT=$(run_checks_for_adapter "$app_adapter" "$WORKSPACE_ROOT/$app_path")
    [[ -n "$APP_REPORT" ]] && REPORT="${REPORT}[${APP_NAMES[$i]}]
${APP_REPORT}
"
  done
else
  GROUP_FILES=("${CHANGED_FILES[@]}")
  REPORT=$(run_checks_for_adapter "$ADAPTER" "$WORKSPACE_ROOT")
fi

# Tell the user only when something needs attention
if printf '%s' "$REPORT" | grep -q '⚠'; then
  df_notify "devflow format/typecheck:
$REPORT"
fi
exit 0
