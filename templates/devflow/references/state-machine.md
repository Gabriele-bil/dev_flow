# Pipeline State Machine

Single source of truth for DevFlow statuses and transitions. Cited by `devflow-discovery`, `devflow-status`, `devflow-resume`, `devflow-recovery`, and `hooks/pre-compact.sh`. Do not invent statuses outside this file.

## Where state lives

| Artifact | Field | Written by |
| --- | --- | --- |
| `task.md` | `**Status:**` | `devflow.task`, `devflow.clarify`, `devflow.pr` |
| `plan.md` | `**Status:**` + `[done]`/`[pending]` markers | pipeline skills at step boundaries |
| `docs/adr/ADR-NNN-[title].md` | `**Status:**` (Accepted/Proposed) | `devflow.discover` |
| `.devflow-state.json` | derived cache — schema in **State file schema** below | `hooks/pre-compact.sh`, `hooks/post-task-create.sh`, skills via **State update snippet** |
| `.devflow-observe-state.json` | hook counters (tool calls, session id, turn timing) | hooks only — skills never read or write it |
| `devflow/features/[NNN]_[name]/.checkpoint.json` | working context (step, slice, decisions, errors_tried) | `devflow.implement` (slice boundaries), `devflow.test` (retry loops); deleted by `devflow.pr` |
| `.devflow-run.json` | autonomous-run marker (feature, from, until) | `devflow.run` Step 0 or `devflow.auto` Step 0; deleted at every run exit |
| `devflow/features/[NNN]_[name]/handoff.md` | context-pressure handoff (current slice, next action, open decisions, errors tried) | `devflow.implement` / `devflow.test` on pressure signal; consumed + deleted by `devflow.resume`; leftover deleted by `devflow.pr` |

`plan.md` is authoritative; `.devflow-state.json` is a derived cache. On conflict → trust `plan.md`, resync via `devflow.recovery`.

## State file schema

`.devflow-state.json` at project root. Canonical keys:

```json
{
  "feature": "003_user-profile",
  "feature_path": "devflow/features/003_user-profile",
  "app": "web",
  "branch": "feat/003_user-profile",
  "task_status": "clarified",
  "plan_status": "implementing",
  "next_step": "devflow.implement",
  "progress": { "done": 4, "pending": 6, "total": 10 },
  "saved_at": "2026-07-17T10:00:00Z",
  "next_feature_number": 4
}
```

| Key | Type | Notes |
| --- | --- | --- |
| `feature` | string | feature dir name `NNN_name` — canonical key |
| `feature_path` | string | `devflow/features/NNN_name` |
| `app` | string | monorepo only (`**App:**` of the feature); omit in single-app repos |
| `branch` | string | `task.md` `**Branch:**` |
| `task_status` | string | `task.md` `**Status:**` (task statuses below) |
| `plan_status` | string | `plan.md` `**Status:**` (plan statuses below); absent before plan |
| `next_step` | string | `devflow.<step>` per status table |
| `progress` | object | `{done, pending, total}` File List markers |
| `saved_at` | string | ISO-8601 UTC of last write |
| `next_feature_number` | int | next free `NNN`; readers also accept legacy string form (`"004"`) |

Rules:

- `active_feature` = legacy alias of `feature`. Read `.feature // .active_feature`; never write it (snippet below deletes it on write).
- Merge, never overwrite: each writer sets only keys it owns; unknown keys preserved.
- Hook counters (tool-call count, session id, turn timing) live in `.devflow-observe-state.json`, owned by hooks — skills never read or write it.

## Active feature resolution

Every skill/command needing "the active feature" without explicit argument uses this order — never "highest `NNN`", "latest", or "most recently modified":

1. **Explicit argument** — feature dir (`NNN_name`), `NNN`, or path to its `task.md`/`plan.md`.
2. **State file** — `.feature // .active_feature` from `.devflow-state.json`, when `devflow/features/<feature>/` exists and feature not terminal.
3. **Lowest-numbered open feature** — ascending `devflow/features/[NNN]_*/`, first one that is:
   - not terminal (terminal = `plan.md` Status `pr-opened`, or no `plan.md` and `task.md` Status `done`)
   - not `blocked` (`plan.md` Status)
   - unblocked (every `TASK-NNN` in `task.md` `**Blockers:**` is terminal; `none`/absent = unblocked)
4. **Ask user** — nothing resolves, or user intent contradicts the result. List open features (`NNN_name` + status).

Resolved feature must still pass the calling skill's input contract (e.g. `devflow.implement` needs `plan.md` Status `ready`/`implementing`). Contract fails → stop, report feature + status, suggest the step it needs — never hop silently to another feature. Status always read from `plan.md` (then `task.md`), never from the state file.

Shell form (steps 2–3; prints `NNN_name` or nothing → step 4):

```bash
_st() { grep -m1 '^\*\*Status:\*\*' "$1" 2>/dev/null | sed 's/^\*\*Status:\*\*[[:space:]]*//; s/[[:space:]]*$//' | tr -d '\r'; }
_terminal() { if [ -f "$1/plan.md" ]; then [ "$(_st "$1/plan.md")" = "pr-opened" ]; else [ "$(_st "$1/task.md")" = "done" ]; fi; }
_open() {
  _terminal "$1" && return 1
  [ "$(_st "$1/plan.md")" = "blocked" ] && return 1
  for id in $(grep -m1 '^\*\*Blockers:\*\*' "$1/task.md" 2>/dev/null | grep -oE '[0-9]{3}'); do
    b=$(ls -d devflow/features/"${id}"_* 2>/dev/null | head -1)
    [ -n "$b" ] && ! _terminal "$b" && return 1
  done; return 0; }
FEATURE=$(jq -r '.feature // .active_feature // empty' .devflow-state.json 2>/dev/null)
{ [ -n "$FEATURE" ] && [ -d "devflow/features/$FEATURE" ] && ! _terminal "devflow/features/$FEATURE"; } || FEATURE=""
if [ -z "$FEATURE" ]; then
  for d in $(ls -d devflow/features/[0-9][0-9][0-9]_*/ 2>/dev/null | sort); do
    d=${d%/}; _open "$d" && { FEATURE=${d##*/}; break; }
  done
fi
echo "$FEATURE"
```

## task.md statuses

```text
draft → clarified → done
draft → done          (clarify skipped)
```

## plan.md statuses

| Status | Meaning | Set by | next_step |
| --- | --- | --- | --- |
| `ready` | Plan approved, not started | `devflow.plan` Step 5 | `devflow.implement` |
| `implementing` | Implement in progress | `devflow.implement` entry (Step 4) | `devflow.implement` (resume) |
| `implemented` | All File List entries `[done]` | `devflow.implement` exit (Step 8) | `devflow.beautify` |
| `beautified` | Multi-axis review applied | `devflow.beautify` exit (Step 6) | `devflow.test` |
| `tested` | Tests pass + `verification.md` has no FAIL | `devflow.test` exit (Step 7) | `devflow.ship` |
| `shipped` | Ship gate passed | `devflow.ship` Step 5 | `devflow.pr` |
| `pr-opened` | PR open toward main | `devflow.pr` Step 6 | — (pipeline complete) |
| `blocked` | Escalation ladder Level 5 | any skill per `references/escalation-ladder.md` | `devflow.recovery` |

## Legal transitions

```text
ready → implementing → implemented → beautified → tested → shipped → pr-opened
hotfix fast-track: ready → implementing → implemented → tested → shipped → pr-opened (beautify skipped, quick gate)
any active status → blocked          (escalation ladder Level 5)
blocked → [status recovery resolves] (devflow.recovery, user-confirmed)
tested → shipped requires verification.md with zero FAIL verdicts
```

Backward transitions (`beautified` → `implemented` or `implementing` → `ready` via `devflow.rollback`, `implemented` → `implementing` after backprop re-work) allowed via `devflow.rollback`, `devflow.recovery`, or `devflow.backprop` with explicit user confirmation — never silently.

## State update snippet

Run after editing `plan.md` / `task.md` `**Status:**` at any step boundary. Merges into existing file (never overwrites), writes atomically, skips silently when `jq` missing:

```bash
command -v jq >/dev/null 2>&1 && {
  tmp=$(mktemp .devflow-state.json.XXXXXX) &&
  { [ -s .devflow-state.json ] && cat .devflow-state.json || echo '{}'; } |
    jq --arg f "<NNN_name>" --arg s "<status>" --arg n "<next_step>" \
       '. + {feature: $f, feature_path: ("devflow/features/" + $f), plan_status: $s, next_step: $n, saved_at: (now | todate)} | del(.active_feature)' \
       > "$tmp" && mv "$tmp" .devflow-state.json || rm -f "$tmp"
}
```

Replace `<NNN_name>`, `<status>`, `<next_step>` per the table above. Task-level writers (`devflow.task`, `devflow.clarify`, `devflow.pr` for task `done`) set `task_status` instead of / besides `plan_status`. Other owned keys (`branch`, `task_status`, `app`, `progress`) → add `--arg` + key inside the same object; never drop keys you do not own. Corrupt JSON → jq fails, file untouched → `devflow.recovery`. Full snapshot (progress, file lists) still refreshed by `hooks/pre-compact.sh` at compaction.

## Checkpoint file (per feature)

`devflow/features/[NNN]_[name]/.checkpoint.json` — working context `[done]` markers cannot hold: mid-implement decisions, constraints discovered, errors already tried. Surviving file = interrupted-work signal.

Schema (6 fields max — no engine-oriented extras):

```json
{
  "step": "devflow.implement",
  "slice": "Slice 2 — state + data flow",
  "decisions": ["repository pattern over direct client — matches registry precedent"],
  "constraints": ["API rate limit 10 req/s — batch calls"],
  "errors_tried": ["mock returned null: fixed provider override, not the model"],
  "updated_at": "2026-07-17T10:00:00Z"
}
```

Lifecycle:

- Written by `devflow.implement` at each slice boundary (Step 4) and by `devflow.test` after each failed retry cycle
- Read by `devflow.resume` (Step 1) and `devflow.recovery` (Step 3 diagnosis)
- Deleted by `devflow.pr` before staging (Step 2) — never committed
- Atomic rewrite: write `.checkpoint.json.tmp` → `mv`

Checkpoint update snippet (skips silently when `jq` missing):

```bash
command -v jq >/dev/null 2>&1 && jq -n \
  --arg step "<step>" --arg slice "<current slice>" \
  --argjson dec '["<decision>"]' --argjson con '["<constraint>"]' --argjson err '["<error tried>"]' \
  '{step: $step, slice: $slice, decisions: $dec, constraints: $con, errors_tried: $err, updated_at: (now | todate)}' \
  > "devflow/features/<NNN>_<name>/.checkpoint.json.tmp" && \
  mv "devflow/features/<NNN>_<name>/.checkpoint.json.tmp" "devflow/features/<NNN>_<name>/.checkpoint.json"
```

Append to existing arrays instead of overwriting: read current file with `jq '.decisions'` first, extend, rewrite.

## Run marker (autonomous mode)

`.devflow-run.json` at project root — presence switches pipeline skills to **run mode**: ambiguity → decision flag in `plan.md` `## Decision flags` (see `devflow-run` skill → Step 2, `devflow-auto` skill → Step 2), intermediate notify gates do not wait for user.

Shared by two orchestrators, distinguished by `from`/`until` vocabulary:

- `devflow.run` — `from`/`until` ∈ `implement` | `beautify` | `test` | `ship`; `feature` known upfront (task.md + plan.md already exist)
- `devflow.auto` — `from: "task"`, `until: "pr"`; `feature` is `null` until its `task` step writes `task.md`, then updated in place; chains all steps from raw idea to open PR, stopping only on major discrepancies and recording minor discrepancies in the PR description

```json
{
  "active": true,
  "feature": "003_user-profile",
  "from": "task",
  "until": "pr",
  "orchestrator": "devflow.auto",
  "started_at": "2026-07-17T10:00:00Z",
  "ship_grader_iterations": 2,
  "ship_grader_iteration_count": 0
}
```

Lifecycle:

- Written by `devflow.run` Step 0 (after user confirmation) or `devflow.auto` Step 0 (immediately on execution); no other skill arms run mode
- Deleted by the owning orchestrator (`devflow.run` or `devflow.auto`) on every exit path (complete, contract failure, block, handoff)
- Never committed — the arming orchestrator appends it to `.gitignore` when present
- Stale marker (found at session start, no run in progress) → `devflow.resume` asks: continue interactively (delete marker) or re-arm the orchestrator named in `from`/`until` (`devflow.run` or `devflow.auto`); corrupted → `devflow.recovery`

Optional fields, read by `devflow-ship` Step 4b (autonomous grader loop):

- `ship_grader_iterations` — max auto-resend cycles for a Required-only (zero Critical) Ship Gate verdict before surfacing the report instead of looping again. Absent → default 2.
- `ship_grader_iteration_count` — running counter for the current feature's ship gate, incremented by `devflow.ship` on each auto-resend, reset to 0 whenever `devflow.run` re-arms the marker for a new `from`/`until` span. Critical findings ignore this counter entirely — they always hard-stop regardless of iterations remaining.

## Handoff file (context pressure)

`devflow/features/[NNN]_[name]/handoff.md` — prose working context written when context pressure is noticeable (host compaction warning, or >20 files into a large plan). Complements `.checkpoint.json` (structured arrays) with narrative state; surviving file = interrupted-under-pressure signal.

```markdown
# Handoff - [NNN]_[feature-name]

**Written:** [ISO timestamp] — context pressure during [step]

## Current slice
[slice name + which File List entries done/pending]

## Next action
[single concrete next step]

## Open decisions
[decisions pending or made-but-unconfirmed]

## Errors tried
[errors hit + fixes already attempted]
```

Lifecycle:

- Written by `devflow.implement` / `devflow.test` on pressure signal, then user told: restart session + `devflow.resume`
- Read by `devflow.resume` (Step 1); deleted by it after resume position confirmed
- Leftover deleted by `devflow.pr` before staging — never committed

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Inventing a status (`in-review`, `wip`) | Only statuses in this file; new status = edit this file first |
| Skipping a status ("implement + beautify in one go") | Each boundary writes its status — resume and hooks depend on it |
| Editing `.devflow-state.json` to change pipeline position | Edit `plan.md` Status; state file is derived cache |
| Setting `tested` with FAIL verdicts in `verification.md` | FAIL = not tested; fix or backprop first |
| Committing `.checkpoint.json` | `devflow.pr` deletes it before `git add .`; checkpoint is session context, not project history |
| Treating a stale `.devflow-run.json` as active autonomy | Run mode dies with its session; resume asks before re-arming |
| Writing handoff.md as a log dump | 4 sections, short — next session needs orientation, not transcript |
| Rewriting checkpoint wholesale each slice (losing prior decisions) | Append to `decisions`/`errors_tried` arrays; only `step`/`slice`/`updated_at` are replaced |
