#!/usr/bin/env bash
# board.sh — DevFlow Deterministic Read-Only Project Board Generator & Sync Engine
#
# Usage:
#   bash board.sh [--sync] [--quiet] [--open] [--port <port>] [--json] [--help]
#
# Modes:
#   Default (initial setup or full run):
#     - Copies templates/devflow/skills/devflow-board/assets/board-template.html
#       to devflow/board/index.html (deterministic, identical UI everywhere).
#     - Generates devflow/board/board-data.js (window.__DEVFLOW_BOARD_DATA__)
#       and devflow/board/board-data.json from devflow/features/**,
#       devflow/plans/project-blueprint.md, docs/adr/*.md, .devflow-state.json,
#       .devflow-metrics.jsonl, and .devflow-timings.jsonl.
#   --sync:
#     - Fast incremental sync invoked by hooks or user.
#     - If devflow/board/index.html does not exist and --quiet is passed, exits 0.
#     - If devflow/board/index.html exists, updates ONLY board-data.js and
#       board-data.json without touching or recreating index.html.
#   --json:
#     - Emits the compiled board JSON payload to stdout and exits 0.
#   --open:
#     - Opens devflow/board/index.html (or http://localhost:<port>) in browser.
#   --port <port>:
#     - Starts a lightweight read-only HTTP server on <port> serving devflow/board/.

set -uo pipefail
export LC_ALL=C

SYNC_ONLY=0
QUIET=0
OPEN_BROWSER=0
SERVE_PORT=""
JSON_STDOUT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync)
      SYNC_ONLY=1
      shift
      ;;
    --quiet|-q)
      QUIET=1
      shift
      ;;
    --open)
      OPEN_BROWSER=1
      shift
      ;;
    --port)
      if [[ -z "${2:-}" || ! "${2:-}" =~ ^[0-9]+$ ]]; then
        [[ "$QUIET" -eq 0 ]] && echo "ERROR: --port requires a valid numeric port (e.g. --port 4173)" >&2
        [[ "$QUIET" -eq 1 ]] && exit 0 || exit 1
      fi
      SERVE_PORT="$2"
      shift 2
      ;;
    --json)
      JSON_STDOUT=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: bash board.sh [--sync] [--quiet] [--open] [--port <port>] [--json]

Options:
  --sync         Regenerate devflow/board/board-data.js without recreating index.html
  --quiet, -q    Suppress output and exit 0 on non-fatal errors (used by hooks)
  --open         Open the generated board in the default system browser
  --port <port>  Serve devflow/board/ over local HTTP on the specified port
  --json         Print the compiled board JSON data to stdout
  --help, -h     Show this help message
EOF
      exit 0
      ;;
    *)
      [[ "$QUIET" -eq 0 ]] && echo "ERROR: Unknown option: $1" >&2
      [[ "$QUIET" -eq 1 ]] && exit 0 || exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  [[ "$QUIET" -eq 0 ]] && echo "ERROR: jq is required to generate the DevFlow board. Install with: brew install jq" >&2
  [[ "$QUIET" -eq 1 ]] && exit 0 || exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="${DEVFLOW_WORKSPACE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

TEMPLATE_HTML="$PLUGIN_ROOT/skills/devflow-board/assets/board-template.html"
if [[ ! -f "$TEMPLATE_HTML" && -f "$WORKSPACE_ROOT/templates/devflow/skills/devflow-board/assets/board-template.html" ]]; then
  TEMPLATE_HTML="$WORKSPACE_ROOT/templates/devflow/skills/devflow-board/assets/board-template.html"
elif [[ ! -f "$TEMPLATE_HTML" && -f "$WORKSPACE_ROOT/dist/devflow/skills/devflow-board/assets/board-template.html" ]]; then
  TEMPLATE_HTML="$WORKSPACE_ROOT/dist/devflow/skills/devflow-board/assets/board-template.html"
fi

BOARD_DIR="$WORKSPACE_ROOT/devflow/board"
INDEX_HTML="$BOARD_DIR/index.html"
DATA_JS="$BOARD_DIR/board-data.js"
DATA_JSON="$BOARD_DIR/board-data.json"

# If invoked by hook with --sync --quiet and board is not initialized yet, do nothing
if [[ "$SYNC_ONLY" -eq 1 && "$QUIET" -eq 1 && ! -f "$INDEX_HTML" && "$JSON_STDOUT" -eq 0 ]]; then
  exit 0
fi

# Helper: convert YYYY-MM-DD or ISO-8601 timestamp to epoch seconds
to_epoch() {
  local ts="$1"
  [[ -z "$ts" || "$ts" == "null" || "$ts" == "none" ]] && { echo 0; return; }
  if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    ts="${ts}T00:00:00Z"
  fi
  local ep
  ep=$(jq -n --arg t "$ts" '($t | sub("\\.[0-9]+Z$"; "Z") | sub("\\+00:00$"; "Z") | fromdateiso8601) // 0' 2>/dev/null || echo 0)
  [[ -z "$ep" || ! "$ep" =~ ^[0-9]+$ ]] && ep=0
  echo "$ep"
}

# Helper: get file creation/first-commit ISO timestamp and epoch
file_created_iso() {
  local fp="$1"
  [[ ! -f "$fp" ]] && { echo ""; return; }
  local git_ts=""
  git_ts=$(git -C "$WORKSPACE_ROOT" log --diff-filter=A --follow --format=%aI -1 -- "$fp" 2>/dev/null | head -1 || true)
  if [[ -n "$git_ts" ]]; then
    echo "$git_ts"
    return
  fi
  # Fallback to file mtime
  file_modified_iso "$fp"
}

file_modified_iso() {
  local fp="$1"
  [[ ! -f "$fp" ]] && { echo ""; return; }
  local mtime=""
  if stat -f "%m" "$fp" >/dev/null 2>&1; then
    mtime=$(stat -f "%m" "$fp" 2>/dev/null)
  else
    mtime=$(stat -c "%Y" "$fp" 2>/dev/null)
  fi
  if [[ -n "$mtime" && "$mtime" =~ ^[0-9]+$ ]]; then
    jq -n --argjson m "$mtime" '($m | todateiso8601)' | tr -d '"' 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# Helper: extract markdown frontmatter / header bold key: **Key:** value
extract_md_field() {
  local file="$1" key="$2"
  [[ ! -f "$file" ]] && { echo ""; return; }
  grep -m1 -E "^\*\*${key}:\*\*" "$file" 2>/dev/null \
    | sed -E "s/^\*\*${key}:\*\*[[:space:]]*//" \
    | sed -E 's/<!--.*-->//' \
    | tr -d '\r\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true
}

# Helper: extract H1 title from markdown
extract_md_title() {
  local file="$1"
  [[ ! -f "$file" ]] && { echo ""; return; }
  grep -m1 -E "^# " "$file" 2>/dev/null \
    | sed -E 's/^#[[:space:]]+(Task[[:space:]]*-[[:space:]]*|Plan[[:space:]]*-[[:space:]]*|Verification[[:space:]]*-[[:space:]]*)?//' \
    | tr -d '\r\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true
}

NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROJECT_NAME=$(basename "$WORKSPACE_ROOT")
CURRENT_BRANCH=$(git -C "$WORKSPACE_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

STATE_FILE="${DEVFLOW_STATE_FILE:-$WORKSPACE_ROOT/.devflow-state.json}"
METRICS_FILE="${DEVFLOW_METRICS_LOG:-$WORKSPACE_ROOT/.devflow-metrics.jsonl}"
TIMINGS_FILE="${DEVFLOW_TIMINGS_LOG:-$WORKSPACE_ROOT/.devflow-timings.jsonl}"

STATE_JSON="{}"
if [[ -f "$STATE_FILE" ]] && jq -e . "$STATE_FILE" >/dev/null 2>&1; then
  STATE_JSON=$(cat "$STATE_FILE")
fi

ACTIVE_FEATURE=$(printf '%s' "$STATE_JSON" | jq -r '.feature // .active_feature // empty' 2>/dev/null || true)
NEXT_STEP=$(printf '%s' "$STATE_JSON" | jq -r '.next_step // empty' 2>/dev/null || true)

# Load all metrics & timings entries into JSON arrays
ALL_METRICS_JSON="[]"
if [[ -f "$METRICS_FILE" && -s "$METRICS_FILE" ]]; then
  ALL_METRICS_JSON=$(jq -s '.' "$METRICS_FILE" 2>/dev/null || echo "[]")
fi

ALL_TIMINGS_JSON="[]"
if [[ -f "$TIMINGS_FILE" && -s "$TIMINGS_FILE" ]]; then
  ALL_TIMINGS_JSON=$(jq -s '.' "$TIMINGS_FILE" 2>/dev/null || echo "[]")
fi

# Parse global documents: devflow/plans/project-blueprint.md & docs/adr/*.md
BLUEPRINT_MD=""
BLUEPRINT_PATH=""
if [[ -f "$WORKSPACE_ROOT/devflow/plans/project-blueprint.md" ]]; then
  BLUEPRINT_PATH="devflow/plans/project-blueprint.md"
  BLUEPRINT_MD=$(cat "$WORKSPACE_ROOT/devflow/plans/project-blueprint.md" 2>/dev/null || true)
elif [[ -d "$WORKSPACE_ROOT/devflow/plans" ]]; then
  FIRST_BP=$(find "$WORKSPACE_ROOT/devflow/plans" -maxdepth 1 -name "*-blueprint.md" 2>/dev/null | sort | head -1 || true)
  if [[ -n "$FIRST_BP" && -f "$FIRST_BP" ]]; then
    BLUEPRINT_PATH="${FIRST_BP#"$WORKSPACE_ROOT/"}"
    BLUEPRINT_MD=$(cat "$FIRST_BP" 2>/dev/null || true)
  fi
fi

ADRS_TMP=$(mktemp)
echo "[]" > "$ADRS_TMP"
if [[ -d "$WORKSPACE_ROOT/docs/adr" ]]; then
  while IFS= read -r adr_file; do
    [[ -z "$adr_file" || ! -f "$adr_file" ]] && continue
    adr_base=$(basename "$adr_file")
    [[ "$adr_base" == "README.md" ]] && continue
    adr_rel="${adr_file#"$WORKSPACE_ROOT/"}"
    adr_title=$(grep -m1 -E "^# " "$adr_file" 2>/dev/null | sed -E 's/^#[[:space:]]+//' | tr -d '\r\n' || echo "$adr_base")
    adr_status=$(extract_md_field "$adr_file" "Status")
    [[ -z "$adr_status" ]] && adr_status="Accepted"
    jq --arg id "${adr_base%.md}" \
       --arg title "$adr_title" \
       --arg path "$adr_rel" \
       --arg status "$adr_status" \
       --rawfile content "$adr_file" \
       '. + [{id: $id, title: $title, path: $path, status: $status, content: $content}]' \
       "$ADRS_TMP" > "${ADRS_TMP}.next" && mv "${ADRS_TMP}.next" "$ADRS_TMP"
  done < <(find "$WORKSPACE_ROOT/docs/adr" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
fi
ADRS_JSON=$(cat "$ADRS_TMP")
rm -f "$ADRS_TMP"

# Scan devflow/features/*
TASKS_TMP=$(mktemp)
echo "[]" > "$TASKS_TMP"

if [[ -d "$WORKSPACE_ROOT/devflow/features" ]]; then
  while IFS= read -r feat_dir; do
    [[ -z "$feat_dir" || ! -d "$feat_dir" ]] && continue
    folder_slug=$(basename "$feat_dir")
    # Match NNN_slug or any feature folder containing task.md/plan.md
    task_file="$feat_dir/task.md"
    plan_file="$feat_dir/plan.md"
    verif_file="$feat_dir/verification.md"

    if [[ ! -f "$task_file" && ! -f "$plan_file" ]]; then
      continue
    fi

    nnn=$(echo "$folder_slug" | grep -oE '^[0-9]{3}' || echo "")
    if [[ -n "$nnn" ]]; then
      default_id="TASK-${nnn}"
    else
      default_id="TASK-${folder_slug}"
    fi

    task_id=$(extract_md_field "$task_file" "ID")
    [[ -z "$task_id" ]] && task_id="$default_id"

    title=$(extract_md_title "$task_file")
    [[ -z "$title" ]] && title=$(extract_md_title "$plan_file")
    [[ -z "$title" ]] && title="$folder_slug"

    task_date=$(extract_md_field "$task_file" "Date")
    task_status=$(extract_md_field "$task_file" "Status" | tr '[:upper:]' '[:lower:]')
    [[ -z "$task_status" ]] && task_status="draft"

    branch=$(extract_md_field "$task_file" "Branch")
    [[ -z "$branch" ]] && branch="feat/${folder_slug}"

    app_name=$(extract_md_field "$task_file" "App")
    [[ -z "$app_name" ]] && app_name=$(extract_md_field "$plan_file" "App")

    adrs_raw=$(extract_md_field "$task_file" "ADRs")
    [[ -z "$adrs_raw" ]] && adrs_raw=$(extract_md_field "$plan_file" "ADRs")

    blockers_raw=$(extract_md_field "$task_file" "Blockers")
    unlocks_raw=$(extract_md_field "$task_file" "Unlocks")

    # Fallback: if Blockers/Unlocks not in task.md, check project-blueprint.md table if present
    if [[ -z "$blockers_raw" && -n "$BLUEPRINT_MD" && -n "$nnn" ]]; then
      bp_line=$(printf '%s\n' "$BLUEPRINT_MD" | grep -E "\|[[:space:]]*(TASK-)?0*${nnn#0}[[:space:]]*\|" | head -1 || true)
      if [[ -n "$bp_line" ]]; then
        blockers_raw=$(echo "$bp_line" | awk -F'|' '{print $5}' | tr -d '\r\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true)
        unlocks_raw=$(echo "$bp_line" | awk -F'|' '{print $6}' | tr -d '\r\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' || true)
      fi
    fi

    plan_status=""
    complexity=""
    if [[ -f "$plan_file" ]]; then
      plan_status=$(extract_md_field "$plan_file" "Status" | tr '[:upper:]' '[:lower:]')
      [[ -z "$plan_status" ]] && plan_status="ready"
      complexity=$(extract_md_field "$plan_file" "Complexity")
    fi

    verif_result=""
    if [[ -f "$verif_file" ]]; then
      verif_result=$(extract_md_field "$verif_file" "Result")
    fi

    # Determine Kanban column from task.md Status and plan.md Status
    # Columns:
    #   1. draft_clarified      ("Draft / Clarified")
    #   2. planned_ready        ("Planned / Ready")
    #   3. in_progress          ("In Progress")
    #   4. implemented_verified ("Implemented / Verified")
    #   5. pr_opened_done       ("PR Opened / Done")
    kanban_col="draft_clarified"
    if [[ "$task_status" == "done" || "$plan_status" == "pr-opened" ]]; then
      kanban_col="pr_opened_done"
    elif [[ "$plan_status" == "implemented" || "$plan_status" == "beautified" || "$plan_status" == "tested" || "$plan_status" == "shipped" ]]; then
      kanban_col="implemented_verified"
    elif [[ "$plan_status" == "implementing" || "$plan_status" == "blocked" ]]; then
      kanban_col="in_progress"
    elif [[ -n "$plan_status" && "$plan_status" == "ready" ]]; then
      kanban_col="planned_ready"
    else
      kanban_col="draft_clarified"
    fi

    # Vertical Slices & Checklist progress in plan.md and task.md
    slices_done=0
    slices_total=0
    if [[ -f "$plan_file" ]]; then
      done_h=$(grep -cE "^###.*\[done\]" "$plan_file" 2>/dev/null; true)
      pend_h=$(grep -cE "^###.*\[pending\]" "$plan_file" 2>/dev/null; true)
      done_h=$(echo "$done_h" | tr -d '[:space:]')
      pend_h=$(echo "$pend_h" | tr -d '[:space:]')
      [[ -z "$done_h" ]] && done_h=0
      [[ -z "$pend_h" ]] && pend_h=0
      if [[ $((done_h + pend_h)) -gt 0 ]]; then
        slices_done=$done_h
        slices_total=$((done_h + pend_h))
      else
        chk_done=$(grep -cE "^[[:space:]]*-[[:space:]]*\[[xX]\]" "$plan_file" 2>/dev/null; true)
        chk_pend=$(grep -cE "^[[:space:]]*-[[:space:]]*\[[[:space:]]\]" "$plan_file" 2>/dev/null; true)
        chk_done=$(echo "$chk_done" | tr -d '[:space:]')
        chk_pend=$(echo "$chk_pend" | tr -d '[:space:]')
        [[ -z "$chk_done" ]] && chk_done=0
        [[ -z "$chk_pend" ]] && chk_pend=0
        slices_done=$chk_done
        slices_total=$((chk_done + chk_pend))
      fi
    fi

    ac_done=0
    ac_total=0
    if [[ -f "$task_file" ]]; then
      ac_d=$(grep -cE "^[[:space:]]*-[[:space:]]*\[[xX]\]" "$task_file" 2>/dev/null; true)
      ac_p=$(grep -cE "^[[:space:]]*-[[:space:]]*\[[[:space:]]\]" "$task_file" 2>/dev/null; true)
      ac_d=$(echo "$ac_d" | tr -d '[:space:]')
      ac_p=$(echo "$ac_p" | tr -d '[:space:]')
      [[ -z "$ac_d" ]] && ac_d=0
      [[ -z "$ac_p" ]] && ac_p=0
      ac_done=$ac_d
      ac_total=$((ac_d + ac_p))
      if [[ "$kanban_col" == "pr_opened_done" && "$ac_total" -gt 0 && "$ac_done" -eq 0 ]]; then
        if [[ "$verif_result" == "PASS" || "$task_status" == "done" ]]; then
          ac_done=$ac_total
        fi
      fi
    fi

    # File timestamps for fallback lead-time and command timeline synthesis
    task_created_at=$(file_created_iso "$task_file")
    task_modified_at=$(file_modified_iso "$task_file")
    plan_created_at=$(file_created_iso "$plan_file")
    plan_modified_at=$(file_modified_iso "$plan_file")
    verif_modified_at=$(file_modified_iso "$verif_file")

    [[ -z "$task_created_at" && -n "$task_date" ]] && task_created_at="${task_date}T08:00:00Z"

    # Parse Blockers and Unlocks into clean arrays of normalized TASK-NNN IDs
    blockers_json=$(printf '%s' "${blockers_raw:-none}" | jq -R '
      split(",")
      | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
      | map(select(length > 0 and (ascii_downcase != "none") and . != "-" and . != "—"))
      | map(
          if test("^[0-9]{3}$") then "TASK-" + .
          elif test("^[0-9]{3}_") then "TASK-" + (capture("^(?<n>[0-9]{3})_").n)
          elif test("^TASK-[0-9]{3}"; "i") then (capture("^(?<id>TASK-[0-9]{3})"; "i").id | ascii_upcase)
          else . end
        )
    ' 2>/dev/null || echo "[]")

    unlocks_json=$(printf '%s' "${unlocks_raw:-none}" | jq -R '
      split(",")
      | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
      | map(select(length > 0 and (ascii_downcase != "none") and . != "-" and . != "—"))
      | map(
          if test("^[0-9]{3}$") then "TASK-" + .
          elif test("^[0-9]{3}_") then "TASK-" + (capture("^(?<n>[0-9]{3})_").n)
          elif test("^TASK-[0-9]{3}"; "i") then (capture("^(?<id>TASK-[0-9]{3})"; "i").id | ascii_upcase)
          else . end
        )
    ' 2>/dev/null || echo "[]")

    adrs_list_json=$(printf '%s' "${adrs_raw:-none}" | jq -R '
      split(",")
      | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
      | map(select(length > 0 and (ascii_downcase != "none") and . != "-" and . != "—"))
    ' 2>/dev/null || echo "[]")

    # Read Markdown contents safely
    task_md_arg=()
    if [[ -f "$task_file" ]]; then
      task_md_arg=(--rawfile task_md "$task_file")
    else
      task_md_arg=(--arg task_md "")
    fi

    plan_md_arg=()
    if [[ -f "$plan_file" ]]; then
      plan_md_arg=(--rawfile plan_md "$plan_file")
    else
      plan_md_arg=(--arg plan_md "")
    fi

    verif_md_arg=()
    if [[ -f "$verif_file" ]]; then
      verif_md_arg=(--rawfile verif_md "$verif_file")
    else
      verif_md_arg=(--arg verif_md "")
    fi

    # Build command timeline & telemetry for this task from .devflow-timings.jsonl and .devflow-metrics.jsonl
    # Match by folder_slug (e.g. 001_foo), short slug (foo), or task_id (TASK-001 / 001)
    short_slug="${folder_slug#[0-9][0-9][0-9]_}"
    task_timings_json=$(jq -n \
      --arg slug "$folder_slug" \
      --arg short "$short_slug" \
      --arg tid "$task_id" \
      --arg nnn "$nnn" \
      --arg task_status "$task_status" \
      --arg plan_status "$plan_status" \
      --arg verif_res "$verif_result" \
      --arg t_create "$task_created_at" \
      --arg t_mod "$task_modified_at" \
      --arg p_create "$plan_created_at" \
      --arg p_mod "$plan_modified_at" \
      --arg v_mod "$verif_modified_at" \
      --argjson timings "$ALL_TIMINGS_JSON" \
      --argjson metrics "$ALL_METRICS_JSON" \
      '
      def matches_feat($f):
        ($f != null and $f != "") and (
          $f == $slug or
          $f == $short or
          $f == $tid or
          ($nnn != "" and ($f | startswith($nnn + "_")))
        );

      def norm_cmd($c):
        if $c == null or $c == "" then "unknown"
        else ($c | sub("^/devflow\\."; "") | sub("^devflow\\."; "") | sub("^devflow-"; ""))
        end;

      # 1. Explicit timing entries from .devflow-timings.jsonl
      ([ $timings[] | select(matches_feat(.active_feature // .feature)) | {
          command: norm_cmd(.command // .step),
          step: (.step // .command // "unknown"),
          started_at: (.started_at // .ts),
          ended_at: (.ended_at // .ts),
          duration_sec: (.duration_sec // 0),
          input_tokens: (.input_tokens // 0),
          output_tokens: (.output_tokens // 0),
          total_tokens: ((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)),
          estimated_cost_usd: (.estimated_cost_usd // 0),
          model: (.model // null),
          source: "timings"
      } ]) as $explicit_timings |

      # 2. Metrics entries from .devflow-metrics.jsonl for this feature
      ([ $metrics[] | select(matches_feat(.active_feature // .feature)) ]) as $feat_metrics |

      # Group metrics by step if not already covered by explicit timings
      (if ($explicit_timings | length) > 0 then
        $explicit_timings
      elif ($feat_metrics | length) > 0 then
        ($feat_metrics | group_by(.command // .step // "implement") | map({
          command: norm_cmd(.[0].command // .[0].step // "implement"),
          step: (.[0].step // "implement"),
          started_at: (.[0].started_at // .[0].ts),
          ended_at: (.[-1].ended_at // .[-1].ts),
          duration_sec: (map(.duration_sec // 0) | add // 0),
          input_tokens: (map(.input_tokens // 0) | add // 0),
          output_tokens: (map(.output_tokens // 0) | add // 0),
          total_tokens: (map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // 0),
          estimated_cost_usd: ((((map(.estimated_cost_usd // 0) | add // 0) * 10000) | round) / 10000),
          model: (.[-1].model // null),
          source: "metrics"
        }))
      else
        # 3. Synthesize artifact milestone timeline when no JSONL telemetry was recorded yet
        (
          (if $t_create != "" then [{
            command: "task",
            step: "devflow.task",
            started_at: $t_create,
            ended_at: (if $t_mod != "" then $t_mod else $t_create end),
            duration_sec: 0,
            input_tokens: 0,
            output_tokens: 0,
            total_tokens: 0,
            estimated_cost_usd: 0,
            model: null,
            source: "artifact"
          }] else [] end)
          +
          (if $p_create != "" then [{
            command: "plan",
            step: "devflow.plan",
            started_at: $p_create,
            ended_at: $p_create,
            duration_sec: 0,
            input_tokens: 0,
            output_tokens: 0,
            total_tokens: 0,
            estimated_cost_usd: 0,
            model: null,
            source: "artifact"
          }] else [] end)
          +
          (if ($plan_status == "implementing" or $plan_status == "implemented" or $plan_status == "beautified" or $plan_status == "tested" or $plan_status == "shipped" or $plan_status == "pr-opened") and $p_mod != "" then [{
            command: "implement",
            step: "devflow.implement",
            started_at: (if $p_create != "" then $p_create else $p_mod end),
            ended_at: $p_mod,
            duration_sec: 0,
            input_tokens: 0,
            output_tokens: 0,
            total_tokens: 0,
            estimated_cost_usd: 0,
            model: null,
            source: "artifact"
          }] else [] end)
          +
          (if $v_mod != "" then [{
            command: "test",
            step: "devflow.test",
            started_at: (if $p_mod != "" then $p_mod else $v_mod end),
            ended_at: $v_mod,
            duration_sec: 0,
            input_tokens: 0,
            output_tokens: 0,
            total_tokens: 0,
            estimated_cost_usd: 0,
            model: null,
            source: "artifact"
          }] else [] end)
          +
          (if ($plan_status == "pr-opened" or $task_status == "done") and ($v_mod != "" or $p_mod != "") then [{
            command: "pr",
            step: "devflow.pr",
            started_at: (if $v_mod != "" then $v_mod else $p_mod end),
            ended_at: (if $p_mod != "" then $p_mod else $v_mod end),
            duration_sec: 0,
            input_tokens: 0,
            output_tokens: 0,
            total_tokens: 0,
            estimated_cost_usd: 0,
            model: null,
            source: "artifact"
          }] else [] end)
        )
      end) as $timeline |

      ($timeline | sort_by(.started_at // "")) as $sorted |
      ($sorted | map(.duration_sec // 0) | add // 0) as $total_dur |
      ($feat_metrics | map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // ($sorted | map(.total_tokens // 0) | add // 0)) as $tot_tok |
      ((((($feat_metrics | map(.estimated_cost_usd // 0) | add // ($sorted | map(.estimated_cost_usd // 0) | add // 0)) * 10000) | round) / 10000)) as $tot_cost |
      (if ($sorted | length) > 0 then $sorted[0].started_at else ($t_create // null) end) as $first_start |
      (if ($sorted | length) > 0 then $sorted[-1].ended_at else ($p_mod // $t_mod // null) end) as $last_end |
      {
        commands: $sorted,
        total_duration_sec: $total_dur,
        total_tokens: $tot_tok,
        estimated_cost_usd: $tot_cost,
        first_started_at: $first_start,
        last_ended_at: $last_end
      }
      ' 2>/dev/null)

    first_started_at=$(printf '%s' "$task_timings_json" | jq -r '.first_started_at // empty')
    last_ended_at=$(printf '%s' "$task_timings_json" | jq -r '.last_ended_at // empty')
    [[ -z "$first_started_at" ]] && first_started_at="$task_created_at"
    [[ -z "$last_ended_at" ]] && last_ended_at="${plan_modified_at:-$task_modified_at}"

    # Calculate lead_time_sec when task reaches done / pr-opened (from task.md creation to done/pr-opened)
    lead_time_sec=0
    if [[ "$kanban_col" == "pr_opened_done" ]]; then
      start_ep=$(to_epoch "${task_created_at:-$first_started_at}")
      end_ep=$(to_epoch "$last_ended_at")
      if [[ "$start_ep" -gt 0 && "$end_ep" -ge "$start_ep" ]]; then
        lead_time_sec=$((end_ep - start_ep))
      fi
    fi
    total_dev_sec=$(printf '%s' "$task_timings_json" | jq -r '.total_duration_sec // 0')
    if [[ "$lead_time_sec" -eq 0 && "$kanban_col" == "pr_opened_done" && "$total_dev_sec" -gt 0 ]]; then
      lead_time_sec=$total_dev_sec
    fi

    jq --arg id "$task_id" \
       --arg nnn "${nnn:-000}" \
       --arg slug "$folder_slug" \
       --arg title "$title" \
       --arg date "$task_date" \
       --arg branch "$branch" \
       --arg app "$app_name" \
       --arg task_status "$task_status" \
       --arg plan_status "${plan_status:-none}" \
       --arg verif_result "${verif_result:-none}" \
       --arg complexity "${complexity:-none}" \
       --arg kanban_col "$kanban_col" \
       --argjson slices_done "$slices_done" \
       --argjson slices_total "$slices_total" \
       --argjson ac_done "$ac_done" \
       --argjson ac_total "$ac_total" \
       --argjson blockers "$blockers_json" \
       --argjson unlocks "$unlocks_json" \
       --argjson adrs "$adrs_list_json" \
       --arg created_at "$task_created_at" \
       --arg first_started_at "$first_started_at" \
       --arg last_ended_at "$last_ended_at" \
       --argjson total_duration_sec "$total_dev_sec" \
       --argjson lead_time_sec "$lead_time_sec" \
       --argjson telemetry "$task_timings_json" \
       --arg has_task "$([[ -f "$task_file" ]] && echo true || echo false)" \
       --arg has_plan "$([[ -f "$plan_file" ]] && echo true || echo false)" \
       --arg has_verif "$([[ -f "$verif_file" ]] && echo true || echo false)" \
       "${task_md_arg[@]}" \
       "${plan_md_arg[@]}" \
       "${verif_md_arg[@]}" \
       '. + [{
          id: $id,
          number: $nnn,
          slug: $slug,
          title: $title,
          date: $date,
          branch: $branch,
          app: (if $app != "" then $app else null end),
          task_status: $task_status,
          plan_status: $plan_status,
          verification_result: $verif_result,
          complexity: $complexity,
          column: $kanban_col,
          slices: {
            done: $slices_done,
            total: $slices_total,
            pct: (if $slices_total > 0 then ((($slices_done / $slices_total) * 100) | round) else (if $kanban_col == "pr_opened_done" then 100 else 0 end) end)
          },
          acceptance_criteria: {
            done: $ac_done,
            total: $ac_total
          },
          blockers: $blockers,
          unlocks: $unlocks,
          adrs: $adrs,
          timings: {
            created_at: (if $created_at != "" then $created_at else null end),
            first_started_at: (if $first_started_at != "" then $first_started_at else null end),
            last_ended_at: (if $last_ended_at != "" then $last_ended_at else null end),
            total_duration_sec: $total_duration_sec,
            lead_time_sec: $lead_time_sec,
            total_tokens: $telemetry.total_tokens,
            estimated_cost_usd: $telemetry.estimated_cost_usd,
            commands: $telemetry.commands
          },
          files: {
            task_path: (if $has_task == "true" then ("devflow/features/" + $slug + "/task.md") else null end),
            plan_path: (if $has_plan == "true" then ("devflow/features/" + $slug + "/plan.md") else null end),
            verification_path: (if $has_verif == "true" then ("devflow/features/" + $slug + "/verification.md") else null end),
            task_md: $task_md,
            plan_md: $plan_md,
            verification_md: $verif_md
          }
       }]' "$TASKS_TMP" > "${TASKS_TMP}.next" && mv "${TASKS_TMP}.next" "$TASKS_TMP"
  done < <(find "$WORKSPACE_ROOT/devflow/features" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi

RAW_TASKS_JSON=$(cat "$TASKS_TMP")
rm -f "$TASKS_TMP"

# Post-process tasks in jq:
# 1. Infer symmetric Unlocks if Task B lists Task A in Blockers
# 2. Compute blocker resolution status (is_blocked, blocker_details)
# 3. Compute DAG edges, topological depth, and Critical Path
# 4. Compute project summary metrics
FINAL_PAYLOAD=$(jq -n \
  --arg generated_at "$NOW_ISO" \
  --arg project_name "$PROJECT_NAME" \
  --arg branch "$CURRENT_BRANCH" \
  --arg active_feature "$ACTIVE_FEATURE" \
  --arg next_step "$NEXT_STEP" \
  --arg blueprint_path "$BLUEPRINT_PATH" \
  --arg blueprint_md "$BLUEPRINT_MD" \
  --argjson state "$STATE_JSON" \
  --argjson adrs "$ADRS_JSON" \
  --argjson raw_tasks "$RAW_TASKS_JSON" \
  --argjson all_metrics "$ALL_METRICS_JSON" \
  '
  # Map task ID -> completion boolean (done or pr-opened)
  (reduce $raw_tasks[] as $t ({}; .[$t.id] = ($t.column == "pr_opened_done"))) as $done_map |
  (reduce $raw_tasks[] as $t ({}; .[$t.id] = $t)) as $task_map |

  # Symmetric unlocks: if B has blocker A, ensure A.unlocks contains B.id
  ($raw_tasks | map(
    . as $t |
    ([ $raw_tasks[] | select((.blockers // []) | index($t.id) != null) | .id ]) as $inferred_unlocks |
    .unlocks = ((.unlocks + $inferred_unlocks) | unique)
  )) as $tasks_with_unlocks |

  # Annotate blocker status per task
  ($tasks_with_unlocks | map(
    . as $t |
    (.blockers | map({
      id: .,
      title: ($task_map[.].title // .),
      slug: ($task_map[.].slug // null),
      resolved: ($done_map[.] // false)
    })) as $b_details |
    ($b_details | map(select(.resolved == false)) | length > 0) as $is_blocked |
    . + {
      blocker_details: $b_details,
      is_blocked: $is_blocked,
      dag_state: (
        if .column == "pr_opened_done" then "completed"
        elif $is_blocked then "blocked"
        elif .column == "in_progress" or .column == "implemented_verified" then "active"
        else "ready"
        end
      )
    }
  )) as $annotated_tasks |

  # Build DAG edges: {from: blocker_id, to: task_id}
  ([
    $annotated_tasks[] as $t |
    $t.blockers[] as $b |
    {
      from: $b,
      to: $t.id,
      resolved: ($done_map[$b] // false)
    }
  ]) as $edges |

  # Compute topological level and Critical Path (longest dependency chain by weight)
  # Since task IDs are ordered 001..NNN, relax levels iteratively (up to N passes)
  ($annotated_tasks | length) as $n |
  (reduce range(0; (if $n > 0 then $n else 1 end)) as $_ (
    (reduce $annotated_tasks[] as $t ({}; .[$t.id] = {
      level: 0,
      weight: (if ($t.timings.total_duration_sec // 0) > 0 then $t.timings.total_duration_sec else 1 end),
      path: [$t.id]
    }));
    . as $acc |
    reduce $annotated_tasks[] as $t ($acc;
      . as $cur |
      if ($t.blockers | length) == 0 then $cur
      else
        ([ $t.blockers[] | select($cur[.] != null) | $cur[.] ]) as $preds |
        if ($preds | length) == 0 then $cur
        else
          ($preds | max_by(.level * 1000000 + .weight)) as $best |
          ($cur[$t.id].weight) as $self_w |
          if ($best.level + 1) > $cur[$t.id].level then
            $cur + { ($t.id): {
              level: ($best.level + 1),
              weight: ($best.weight + $self_w),
              path: ($best.path + [$t.id])
            } }
          else $cur end
        end
      end
    )
  )) as $dag_levels |

  # Critical path is the path with maximum level (and weight tie-breaker)
  (if ($annotated_tasks | length) > 0 then
    ([ $dag_levels[] ] | max_by(.level * 1000000 + .weight).path // [])
  else [] end) as $critical_path |

  # Inject dag_level and on_critical_path into each task
  ($annotated_tasks | map(
    . as $t |
    . + {
      dag_level: ($dag_levels[$t.id].level // 0),
      on_critical_path: (($critical_path | index($t.id)) != null)
    }
  )) as $final_tasks |

  # Project-level summary stats
  ($final_tasks | length) as $total_tasks |
  ($final_tasks | map(select(.column == "pr_opened_done")) | length) as $done_tasks |
  ($final_tasks | map(select(.is_blocked == true)) | length) as $blocked_tasks |
  ($final_tasks | map(select(.column == "in_progress" or .column == "implemented_verified")) | length) as $in_progress_tasks |
  ($final_tasks | map(.timings.total_duration_sec // 0) | add // 0) as $total_dev_sec |
  ($final_tasks | map(.timings.lead_time_sec // 0) | add // 0) as $total_lead_sec |
  ((((($all_metrics | map(.estimated_cost_usd // 0) | add // 0) * 10000) | round) / 10000)) as $total_cost_usd |
  ($all_metrics | map((.input_tokens // 0) + (.output_tokens // 0) + (.cache_creation_tokens // 0) + (.cache_read_tokens // 0)) | add // 0) as $total_tokens |

  {
    schema_version: "1.0",
    generated_at: $generated_at,
    read_only: true,
    project: {
      name: $project_name,
      branch: $branch,
      active_feature: (if $active_feature != "" then $active_feature else null end),
      next_step: (if $next_step != "" then $next_step else null end),
      total_tasks: $total_tasks,
      completed_tasks: $done_tasks,
      in_progress_tasks: $in_progress_tasks,
      blocked_tasks: $blocked_tasks,
      completion_pct: (if $total_tasks > 0 then ((($done_tasks / $total_tasks) * 100) | round) else 0 end),
      total_development_sec: $total_dev_sec,
      total_lead_time_sec: $total_lead_sec,
      total_tokens: $total_tokens,
      total_cost_usd: $total_cost_usd
    },
    columns: [
      { id: "draft_clarified",      label: "Draft / Clarified",      count: ($final_tasks | map(select(.column == "draft_clarified")) | length) },
      { id: "planned_ready",        label: "Planned / Ready",        count: ($final_tasks | map(select(.column == "planned_ready")) | length) },
      { id: "in_progress",          label: "In Progress",            count: ($final_tasks | map(select(.column == "in_progress")) | length) },
      { id: "implemented_verified", label: "Implemented / Verified", count: ($final_tasks | map(select(.column == "implemented_verified")) | length) },
      { id: "pr_opened_done",       label: "PR Opened / Done",       count: ($final_tasks | map(select(.column == "pr_opened_done")) | length) }
    ],
    dag: {
      edges: $edges,
      critical_path: $critical_path,
      max_depth: (if ($final_tasks | length) > 0 then ([ $final_tasks[].dag_level ] | max) else 0 end)
    },
    tasks: $final_tasks,
    documents: {
      blueprint: (if $blueprint_md != "" then { path: $blueprint_path, content: $blueprint_md } else null end),
      adrs: $adrs
    },
    state: $state
  }
  ')

if [[ "$JSON_STDOUT" -eq 1 ]]; then
  printf '%s\n' "$FINAL_PAYLOAD"
  exit 0
fi

mkdir -p "$BOARD_DIR"

# Write index.html ONLY if not in --sync mode OR if index.html does not yet exist
if [[ "$SYNC_ONLY" -eq 0 || ! -f "$INDEX_HTML" ]]; then
  if [[ ! -f "$TEMPLATE_HTML" ]]; then
    [[ "$QUIET" -eq 0 ]] && echo "ERROR: Board template not found at $TEMPLATE_HTML" >&2
    [[ "$QUIET" -eq 1 ]] && exit 0 || exit 1
  fi
  cp "$TEMPLATE_HTML" "$INDEX_HTML"
fi

# Atomically write board-data.json and board-data.js
printf '%s\n' "$FINAL_PAYLOAD" > "${DATA_JSON}.tmp" && mv "${DATA_JSON}.tmp" "$DATA_JSON"
{
  printf '// Auto-generated by DevFlow board.sh — Read-Only Data Manifest\n'
  printf '// Last synced: %s\n' "$NOW_ISO"
  printf 'window.__DEVFLOW_BOARD_DATA__ = '
  printf '%s;\n' "$FINAL_PAYLOAD"
  printf 'if (typeof window.__DEVFLOW_ON_DATA_LOADED__ === "function") { window.__DEVFLOW_ON_DATA_LOADED__(window.__DEVFLOW_BOARD_DATA__); }\n'
} > "${DATA_JS}.tmp" && mv "${DATA_JS}.tmp" "$DATA_JS"

# Ensure devflow/board/ and .devflow-timings.jsonl are gitignored in consumer repo
if [[ -f "$WORKSPACE_ROOT/.gitignore" ]]; then
  if ! grep -qF ".devflow-timings.jsonl" "$WORKSPACE_ROOT/.gitignore" 2>/dev/null; then
    printf '\n# devflow command timing telemetry\n.devflow-timings.jsonl\n' >> "$WORKSPACE_ROOT/.gitignore" 2>/dev/null || true
  fi
  if ! grep -qF "devflow/board/" "$WORKSPACE_ROOT/.gitignore" 2>/dev/null; then
    printf '\n# devflow generated local HTML board\ndevflow/board/\n' >> "$WORKSPACE_ROOT/.gitignore" 2>/dev/null || true
  fi
fi

if [[ "$QUIET" -eq 0 ]]; then
  TOTAL_T=$(printf '%s' "$FINAL_PAYLOAD" | jq -r '.project.total_tasks // 0')
  DONE_T=$(printf '%s' "$FINAL_PAYLOAD" | jq -r '.project.completed_tasks // 0')
  PCT_T=$(printf '%s' "$FINAL_PAYLOAD" | jq -r '.project.completion_pct // 0')
  if [[ "$SYNC_ONLY" -eq 1 ]]; then
    echo "✅ DevFlow Board synced: devflow/board/board-data.js ($DONE_T/$TOTAL_T tasks done · ${PCT_T}%)"
  else
    echo "========================================================================"
    echo "                 📊 DevFlow Project Board Ready"
    echo "========================================================================"
    echo "  Board HTML:      devflow/board/index.html (read-only)"
    echo "  Data Manifest:   devflow/board/board-data.js"
    echo "  Project:         $PROJECT_NAME ($CURRENT_BRANCH)"
    echo "  Active Feature:  ${ACTIVE_FEATURE:-none}"
    echo "  Tasks Tracked:   $TOTAL_T ($DONE_T completed · ${PCT_T}%)"
    echo "  Auto-Sync:       Active via DevFlow hooks on feature/state changes"
    echo "========================================================================"
  fi
fi

if [[ -n "$SERVE_PORT" ]]; then
  if command -v lsof >/dev/null 2>&1 && lsof -iTCP:"$SERVE_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "ERROR: Port $SERVE_PORT is already in use. Choose another port with --port <N>." >&2
    exit 1
  fi
  if command -v python3 >/dev/null 2>&1; then
    [[ "$QUIET" -eq 0 ]] && echo "🌐 Serving DevFlow Board at http://localhost:${SERVE_PORT}/devflow/board/index.html (Ctrl+C to stop)"
    if [[ "$OPEN_BROWSER" -eq 1 ]]; then
      (sleep 0.5 && (open "http://localhost:${SERVE_PORT}/devflow/board/index.html" 2>/dev/null || xdg-open "http://localhost:${SERVE_PORT}/devflow/board/index.html" 2>/dev/null || true)) &
    fi
    cd "$WORKSPACE_ROOT" && exec python3 -m http.server "$SERVE_PORT" --bind 127.0.0.1
  else
    echo "ERROR: python3 is required to serve over HTTP (--port). Open devflow/board/index.html directly instead." >&2
    exit 1
  fi
elif [[ "$OPEN_BROWSER" -eq 1 ]]; then
  open "$INDEX_HTML" 2>/dev/null || xdg-open "$INDEX_HTML" 2>/dev/null || true
fi

exit 0
