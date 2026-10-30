#!/usr/bin/env bash
# devflow-state.sh — pipeline state for every skill, identical on Claude Code
# and Antigravity CLI. Replaces the jq snippets skills used to compose by hand.
# Rules and schemas: references/state-machine.md (plan.md wins over the cache).
#
# Usage (from the project root; [F] = feature: NNN, NNN_name or a path inside it):
#   devflow-state.sh resolve [F]          active feature NNN_name (exit 1 → ask the user)
#   devflow-state.sh status [F]           one line: statuses, next step, progress
#   devflow-state.sh report [F]           report lines for run/auto: files, checks,
#                                         verification, decision flags — computed, not recalled
#   devflow-state.sh set plan|task <status> [F] [--force]
#                                         write **Status:** + merge .devflow-state.json;
#                                         refuses illegal transitions (--force: user-confirmed)
#   devflow-state.sh mark-done <path> [F] File List entry [pending] → [done]
#   devflow-state.sh checkpoint [F] [--step S] [--slice S] [--decision D]... [--constraint C]... [--error E]...
#                                         append to .checkpoint.json (arrays never lose entries)
#   devflow-state.sh sync [F]             rebuild .devflow-state.json from plan.md/task.md
#   devflow-state.sh base                 base branch: origin/HEAD, else main|master|develop|next, else main
#   devflow-state.sh branch <type>/<NNN>_<name>
#                                         switch to the feature branch, creating it from
#                                         origin/<base> (HEAD when offline — the line says so)
#   devflow-state.sh run arm --orchestrator devflow.run|devflow.auto --from X --until Y [--feature F] [--iterations N]
#   devflow-state.sh run feature <NNN_name> | bump | status | disarm
#
# Exit codes: 0 ok · 1 nothing resolved / not found · 2 refused (illegal
# transition, stale marker, failing verification) · 3 grader cap reached (run bump)
# jq is optional: without it markdown is still updated, JSON files are skipped.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../hooks/lib/payload.sh
. "$SCRIPT_DIR/../hooks/lib/payload.sh"

DF_WORKSPACE="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$DF_WORKSPACE" || exit 1
FEATURES_DIR="devflow/features"
STATE_FILE=".devflow-state.json"
RUN_FILE=".devflow-run.json"
HAS_JQ=""; command -v jq >/dev/null 2>&1 && HAS_JQ=1

die() { printf 'devflow-state: %s\n' "$1" >&2; exit "${2:-1}"; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ── Markdown fields ───────────────────────────────────────────────────────────
_st() { grep -m1 '^\*\*Status:\*\*' "$1" 2>/dev/null | sed 's/^\*\*Status:\*\*[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r'; }
_field() { grep -m1 "^\*\*$2:\*\*" "$1" 2>/dev/null | sed "s/^\*\*$2:\*\*[[:space:]]*//; s/[[:space:]]*<!--.*//; s/[[:space:]]*\$//" | tr -d '\r'; }
_terminal() { if [ -f "$1/plan.md" ]; then [ "$(_st "$1/plan.md")" = "pr-opened" ]; else [ "$(_st "$1/task.md")" = "done" ]; fi; }
_open() {
  _terminal "$1" && return 1
  [ "$(_st "$1/plan.md")" = "blocked" ] && return 1
  local id b
  for id in $(grep -m1 '^\*\*Blockers:\*\*' "$1/task.md" 2>/dev/null | grep -oE '[0-9]{3}'); do
    b=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name "${id}_*" 2>/dev/null | sort | head -1)
    [ -n "$b" ] && ! _terminal "$b" && return 1
  done
  return 0
}

# _feature_from_arg <arg> — NNN, NNN_name or any path containing NNN_name.
_feature_from_arg() {
  local a="$1" id d
  id=$(printf '%s' "$a" | grep -oE '(^|/)[0-9]{3}(_[^/]*)?' | head -1 | sed 's#^/##')
  [ -n "$id" ] || return 1
  case "$id" in
    *_*) [ -d "$FEATURES_DIR/$id" ] && { printf '%s' "$id"; return 0; } ;;
  esac
  d=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name "${id%%_*}_*" 2>/dev/null | sort | head -1)
  [ -n "$d" ] && printf '%s' "${d##*/}"
}

# resolve_feature [arg] — state-machine.md → Active feature resolution, steps 1–3.
resolve_feature() {
  local f="" d
  if [ -n "$1" ]; then
    f=$(_feature_from_arg "$1") || true
    [ -n "$f" ] && { printf '%s' "$f"; return 0; }
    return 1
  fi
  if [ -n "$HAS_JQ" ] && [ -s "$STATE_FILE" ]; then
    f=$(jq -r '.feature // .active_feature // empty' "$STATE_FILE" 2>/dev/null)
  fi
  if [ -n "$f" ] && [ -d "$FEATURES_DIR/$f" ] && ! _terminal "$FEATURES_DIR/$f"; then
    printf '%s' "$f"; return 0
  fi
  for d in $(find "$FEATURES_DIR" -maxdepth 1 -type d -name '[0-9][0-9][0-9]_*' 2>/dev/null | sort); do
    _open "$d" && { printf '%s' "${d##*/}"; return 0; }
  done
  return 1
}

need_feature() {
  FEATURE=$(resolve_feature "$1") || die "no active feature${1:+ matching '$1'} — ask the user which feature (list: ls $FEATURES_DIR)"
  FDIR="$FEATURES_DIR/$FEATURE"
}

# ── Status tables ─────────────────────────────────────────────────────────────
PLAN_STATUSES="ready implementing implemented beautified tested shipped pr-opened blocked"
TASK_STATUSES="draft clarified done"

next_step_for() {
  case "$1:$2" in
    plan:ready|plan:implementing) echo "devflow.implement" ;;
    plan:implemented) echo "devflow.beautify" ;;
    plan:beautified) echo "devflow.test" ;;
    plan:tested) echo "devflow.ship" ;;
    plan:shipped) echo "devflow.pr" ;;
    plan:blocked) echo "devflow.recovery" ;;
    task:draft|task:clarified) echo "devflow.plan" ;;
    *) echo "" ;;
  esac
}

# legal <plan|task> <from> <to> — references/state-machine.md → Legal transitions.
legal() {
  local kind="$1" from="$2" to="$3"
  [ "$from" = "$to" ] && return 0
  if [ "$kind" = task ]; then
    case "$from>$to" in ">draft"|"draft>clarified"|"draft>done"|"clarified>done") return 0 ;; esac
    return 1
  fi
  [ "$to" = blocked ] && [ "$from" != pr-opened ] && return 0
  [ "$from" = blocked ] && return 0
  case "$from>$to" in
    ">ready"|"ready>implementing"|"implementing>implemented"|"implemented>beautified") return 0 ;;
    "implemented>tested"|"beautified>tested"|"tested>shipped"|"shipped>pr-opened") return 0 ;;
    "implemented>implementing"|"beautified>implementing"|"tested>implementing"|"shipped>implementing") return 0 ;;
    "implementing>ready"|"implemented>ready"|"beautified>implemented") return 0 ;;
  esac
  return 1
}

progress_json() {
  local plan="$1" n_done n_pending
  n_done=$(grep -cE '^###.*\[done\]' "$plan" 2>/dev/null || true)
  n_pending=$(grep -cE '^###.*\[pending\]' "$plan" 2>/dev/null || true)
  printf '{"done":%d,"pending":%d,"total":%d}' "${n_done:-0}" "${n_pending:-0}" "$(( ${n_done:-0} + ${n_pending:-0} ))"
}

next_feature_number() {
  local n
  n=$(find "$FEATURES_DIR" -maxdepth 1 -type d -name '[0-9][0-9][0-9]_*' 2>/dev/null | sed 's#.*/##' | cut -c1-3 | sort -n | tail -1)
  echo $(( 10#${n:-0} + 1 ))
}

# merge_state — refresh the derived cache for $FEATURE (keys this script owns).
merge_state() {
  [ -n "$HAS_JQ" ] || return 0
  local ps ts ns branch app prog
  ps=$(_st "$FDIR/plan.md"); ts=$(_st "$FDIR/task.md")
  if [ -n "$ps" ]; then ns=$(next_step_for plan "$ps"); else ns=$(next_step_for task "$ts"); fi
  branch=$(_field "$FDIR/task.md" Branch)
  app=$(_field "$FDIR/plan.md" App); [ -n "$app" ] || app=$(_field "$FDIR/task.md" App)
  prog='null'; [ -f "$FDIR/plan.md" ] && prog=$(progress_json "$FDIR/plan.md")
  df_json_update "$STATE_FILE" '
    . + {feature: $f, feature_path: ("devflow/features/" + $f), next_step: $n, saved_at: $at}
    | (if $ps != "" then .plan_status = $ps else del(.plan_status) end)
    | (if $ts != "" then .task_status = $ts else . end)
    | (if $br != "" then .branch = $br else . end)
    | (if $app != "" then .app = $app else . end)
    | (if $prog != null then .progress = $prog else . end)
    | ((.next_feature_number // 0) | tonumber? // 0) as $cur
    | .next_feature_number = ([$cur, $nfn] | max)
    | del(.active_feature)' \
    --arg f "$FEATURE" --arg ps "$ps" --arg ts "$ts" --arg n "$ns" --arg br "$branch" --arg app "$app" \
    --arg at "$(now)" --argjson prog "$prog" --argjson nfn "$(next_feature_number)"
}

status_line() {
  local ps ts ns prog=""
  ps=$(_st "$FDIR/plan.md"); ts=$(_st "$FDIR/task.md")
  if [ -n "$ps" ]; then ns=$(next_step_for plan "$ps"); else ns=$(next_step_for task "$ts"); fi
  if [ -f "$FDIR/plan.md" ]; then
    prog=$(progress_json "$FDIR/plan.md" | sed -E 's/.*"done":([0-9]+).*"total":([0-9]+).*/\1\/\2 files/')
  fi
  printf '%s · task: %s · plan: %s · next: %s%s\n' "$FEATURE" "${ts:-—}" "${ps:-—}" "${ns:-none (pipeline complete)}" "${prog:+ · $prog}"
}

# write_status <file> <status> — replace the first **Status:** line in place.
write_status() {
  local tmp
  grep -q '^\*\*Status:\*\*' "$1" || return 1
  tmp=$(mktemp "$1.XXXXXX") || return 1
  awk -v s="$2" '!done && /^\*\*Status:\*\*/ { print "**Status:** " s; done = 1; next } { print }' "$1" > "$tmp" && mv -f "$tmp" "$1" || { rm -f "$tmp"; return 1; }
}

verification_result() { _field "$FDIR/verification.md" Result | awk '{print $1}'; }

# ── Commands ──────────────────────────────────────────────────────────────────
cmd_set() {
  local kind="$1" to="$2" arg="" force="" file from
  shift 2 || die "usage: set plan|task <status> [feature] [--force]"
  for a in "$@"; do case "$a" in --force) force=1 ;; *) arg="$a" ;; esac; done
  case "$kind" in
    plan) file=plan.md; case " $PLAN_STATUSES " in *" $to "*) ;; *) die "unknown plan status '$to' (valid: $PLAN_STATUSES)" 2 ;; esac ;;
    task) file=task.md; case " $TASK_STATUSES " in *" $to "*) ;; *) die "unknown task status '$to' (valid: $TASK_STATUSES)" 2 ;; esac ;;
    *) die "usage: set plan|task <status> [feature] [--force]" ;;
  esac
  need_feature "$arg"
  [ -f "$FDIR/$file" ] || die "$FDIR/$file not found"
  from=$(_st "$FDIR/$file")
  if [ -z "$force" ] && ! legal "$kind" "$from" "$to"; then
    die "$kind.md: '$from' → '$to' is not a legal transition (references/state-machine.md). Use --force only for a user-confirmed reset." 2
  fi
  if [ "$kind" = plan ] && { [ "$to" = tested ] || [ "$to" = shipped ]; }; then
    [ -f "$FDIR/verification.md" ] || die "$to needs $FDIR/verification.md (devflow.test Step 6b)" 2
    [ "$(verification_result)" != FAIL ] || die "$to refused: verification.md Result is FAIL" 2
  fi
  write_status "$FDIR/$file" "$to" || die "could not write $FDIR/$file"
  merge_state
  printf '%s: %s → %s · ' "$file" "${from:-—}" "$to"
  status_line
}

cmd_mark_done() {
  local path="$1"; shift
  [ -n "$path" ] || die "usage: mark-done <path> [feature]"
  need_feature "$1"
  local plan="$FDIR/plan.md" tmp entry
  [ -f "$plan" ] || die "$plan not found"
  entry=$(grep -E '^###' "$plan" | grep -F "\`$path\`")
  case "$entry" in
    *"[pending]"*) ;;
    *"[done]"*) echo "already [done]: $path"; return 0 ;;
    *) die "no File List entry for \`$path\` in $plan" ;;
  esac
  tmp=$(mktemp "$plan.XXXXXX") || die "mktemp failed"
  awk -v p="\`$path\`" '/^###/ && index($0, p) && /\[pending\]/ { sub(/\[pending\]/, "[done]") } { print }' "$plan" > "$tmp" && mv -f "$tmp" "$plan" || { rm -f "$tmp"; die "could not write $plan"; }
  merge_state
  printf '[done] %s · ' "$path"; status_line
}

cmd_checkpoint() {
  local arg="" step="" slice="" dec=() con=() err=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --step) step="$2"; shift 2 ;;
      --slice) slice="$2"; shift 2 ;;
      --decision) dec+=("$2"); shift 2 ;;
      --constraint) con+=("$2"); shift 2 ;;
      --error) err+=("$2"); shift 2 ;;
      *) arg="$1"; shift ;;
    esac
  done
  need_feature "$arg"
  [ -n "$HAS_JQ" ] || { echo "checkpoint skipped: jq not installed"; return 0; }
  local to_json='$ARGS.positional'
  df_json_update "$FDIR/.checkpoint.json" '
    (if $step != "" then .step = $step else . end)
    | (if $slice != "" then .slice = $slice else . end)
    | .decisions = ((.decisions // []) as $a | $a + ($dec - $a))
    | .constraints = ((.constraints // []) as $a | $a + ($con - $a))
    | .errors_tried = ((.errors_tried // []) as $a | $a + ($err - $a))
    | .updated_at = $at' \
    --arg step "$step" --arg slice "$slice" --arg at "$(now)" \
    --argjson dec "$(jq -n "$to_json" --args ${dec[@]+"${dec[@]}"})" \
    --argjson con "$(jq -n "$to_json" --args ${con[@]+"${con[@]}"})" \
    --argjson err "$(jq -n "$to_json" --args ${err[@]+"${err[@]}"})"
  jq -r '"checkpoint: \(.step // "—") · \(.slice // "—") · \(.decisions | length) decisions · \(.constraints | length) constraints · \(.errors_tried | length) errors tried"' "$FDIR/.checkpoint.json"
}

# count_items <file> <heading> — "- " bullets under "## <heading>".
count_items() {
  awk -v h="## $2" '$0 == h || index($0, h " ") == 1 { on = 1; next } on && /^## / { exit } on && /^- / { n++ } END { print n + 0 }' "$1" 2>/dev/null
}

cmd_report() {
  need_feature "$1"
  local plan="$FDIR/plan.md" ver="$FDIR/verification.md" stamps total ok
  printf 'Feature:       '; status_line
  if [ -f "$plan" ]; then
    printf 'Files:         %s create · %s modify (plan.md File List)\n' \
      "$(grep -cE '^###.*` - create' "$plan" || true)" "$(grep -cE '^###.*` - modify' "$plan" || true)"
  fi
  stamps=$(bash "$SCRIPT_DIR/verify-stamp.sh" show 2>/dev/null)
  printf 'Checks:        %s\n' "$(printf '%s\n' "${stamps:-no stamps}" | sed '2,$s/^/               /')"
  if [ -f "$ver" ]; then
    total=$(grep -cE '\|[[:space:]]*(PASS|FAIL|PARTIAL)[[:space:]]*\|[[:space:]]*$' "$ver" || true)
    ok=$(grep -cE '\|[[:space:]]*(PASS|PARTIAL)[[:space:]]*\|[[:space:]]*$' "$ver" || true)
    printf 'Verification:  %s — %s/%s ACs verified (%s)\n' "$(verification_result)" "$ok" "$total" "$ver"
  else
    echo "Verification:  not written yet"
  fi
  [ -f "$plan" ] && printf 'Flags:         decision flags: %s · deviations: %s (plan.md)\n' \
    "$(count_items "$plan" "Decision flags")" "$(count_items "$plan" "Deviations")"
  return 0
}

base_branch() {
  local b c
  b=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -z "$b" ]; then
    for c in main master develop next; do
      git show-ref --verify --quiet "refs/remotes/origin/$c" && { b="$c"; break; }
    done
  fi
  echo "${b:-main}"
}

cmd_branch() {
  local name="$1" base
  [ -n "$name" ] || die "usage: branch <type>/<NNN>_<name>"
  if [ "$(git branch --show-current 2>/dev/null)" = "$name" ]; then echo "branch: on $name"; return 0; fi
  if git show-ref --verify --quiet "refs/heads/$name"; then
    git switch -q "$name" || die "could not switch to $name (uncommitted changes in the way?)" 2
    echo "branch: switched to existing $name"; return 0
  fi
  base=$(base_branch)
  git fetch -q origin "$base" 2>/dev/null || true
  if git switch -q -c "$name" "origin/$base" 2>/dev/null; then
    echo "branch: created $name from origin/$base"
  else
    git switch -q -c "$name" || die "could not create $name" 2
    echo "branch: created $name from HEAD — origin/$base unavailable (offline or no remote); tell the user"
  fi
}

cmd_run() {
  local sub="$1"; shift
  [ -n "$HAS_JQ" ] || die "run marker needs jq"
  case "$sub" in
    arm)
      local orch="" from="" until="" feat="" iters=2
      while [ $# -gt 0 ]; do
        case "$1" in
          --orchestrator) orch="$2"; shift 2 ;;
          --from) from="$2"; shift 2 ;;
          --until) until="$2"; shift 2 ;;
          --feature) feat="$2"; shift 2 ;;
          --iterations) iters="$2"; shift 2 ;;
          *) die "run arm: unknown option $1" ;;
        esac
      done
      case "$orch" in devflow.run|devflow.auto) ;; *) die "run arm: --orchestrator devflow.run|devflow.auto" ;; esac
      [ -n "$from" ] && [ -n "$until" ] || die "run arm: --from and --until are required"
      [ -e "$RUN_FILE" ] && die "stale $RUN_FILE found — ask the user: delete it (run disarm) or route devflow.recovery" 2
      jq -n --arg o "$orch" --arg from "$from" --arg until "$until" --arg f "$feat" --arg at "$(now)" --argjson n "$iters" \
        '{active: true, feature: (if $f == "" then null else $f end), from: $from, until: $until, orchestrator: $o,
          started_at: $at, ship_grader_iterations: $n, ship_grader_iteration_count: 0}' > "$RUN_FILE"
      df_gitignore "$RUN_FILE"
      echo "run armed: $orch $from → $until${feat:+ · $feat}"
      ;;
    feature)
      [ -f "$RUN_FILE" ] || die "no run marker"
      df_json_update "$RUN_FILE" '.feature = $f' --arg f "$1"
      echo "run feature: $1"
      ;;
    bump)
      [ -f "$RUN_FILE" ] || die "no run marker"
      local cap count
      cap=$(jq -r '.ship_grader_iterations // 2' "$RUN_FILE"); count=$(jq -r '.ship_grader_iteration_count // 0' "$RUN_FILE")
      if [ "$count" -ge "$cap" ]; then echo "grader cap reached: $count/$cap"; exit 3; fi
      df_json_update "$RUN_FILE" '.ship_grader_iteration_count = ((.ship_grader_iteration_count // 0) + 1)'
      echo "grader iteration $((count + 1))/$cap"
      ;;
    status)
      [ -f "$RUN_FILE" ] || { echo "run: inactive"; return 0; }
      jq -r '"run: \(.orchestrator) \(.from) → \(.until) · feature: \(.feature // "—") · grader \(.ship_grader_iteration_count // 0)/\(.ship_grader_iterations // 2)"' "$RUN_FILE" 2>/dev/null \
        || die "$RUN_FILE is corrupt — route devflow.recovery" 2
      ;;
    disarm)
      rm -f "$RUN_FILE"; echo "run disarmed"
      ;;
    *) die "usage: run arm|feature|bump|status|disarm" ;;
  esac
}

case "$1" in
  resolve) resolve_feature "$2" && echo || exit 1 ;;
  status) need_feature "$2"; status_line ;;
  report) cmd_report "$2" ;;
  base) base_branch ;;
  branch) cmd_branch "$2" ;;
  set) shift; cmd_set "$@" ;;
  mark-done) shift; cmd_mark_done "$@" ;;
  checkpoint) shift; cmd_checkpoint "$@" ;;
  sync) need_feature "$2"; merge_state; printf 'synced · '; status_line ;;
  run) shift; cmd_run "$@" ;;
  ""|-h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0" ;;
  *) die "unknown command '$1' (see --help)" ;;
esac
