# Pipeline State Machine

Single source of truth for DevFlow statuses and transitions. Cited by `devflow-discovery`, `devflow-status`, `devflow-resume`, `devflow-recovery`, and `hooks/pre-compact.sh`. Do not invent statuses outside this file.

## Where state lives

| Artifact | Field | Written by |
| --- | --- | --- |
| `task.md` | `**Status:**` | `devflow.task`, `devflow.clarify`, `devflow.pr` |
| `plan.md` | `**Status:**` + `[done]`/`[pending]` markers | pipeline skills at step boundaries |
| `.devflow-state.json` | snapshot (feature, plan_status, next_step, progress) | `hooks/pre-compact.sh`, `hooks/post-task-create.sh`, skills via State update snippet |
| `devflow/features/[NNN]_[name]/.checkpoint.json` | working context (step, slice, decisions, errors_tried) | `devflow.implement` (slice boundaries), `devflow.test` (retry loops); deleted by `devflow.pr` |
| `.devflow-run.json` | autonomous-run marker (feature, from, until) | `devflow.run` Step 0; deleted at every run exit |
| `devflow/features/[NNN]_[name]/handoff.md` | context-pressure handoff (current slice, next action, open decisions, errors tried) | `devflow.implement` / `devflow.test` on pressure signal; consumed + deleted by `devflow.resume`; leftover deleted by `devflow.pr` |

`plan.md` is authoritative; `.devflow-state.json` is a derived cache. On conflict → trust `plan.md`, resync via `devflow.recovery`.

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
any active status → blocked          (escalation ladder Level 5)
blocked → [status recovery resolves] (devflow.recovery, user-confirmed)
tested → shipped requires verification.md with zero FAIL verdicts
```

Backward transitions (`implemented` → `implementing` after backprop re-work, etc.) allowed only via `devflow.recovery` or `devflow.backprop` with explicit user confirmation — never silently.

## State update snippet

Run after editing `plan.md` `**Status:**` at any step boundary. Skips silently when `jq` missing:

```bash
command -v jq >/dev/null 2>&1 && { [ -f .devflow-state.json ] || echo '{}' > .devflow-state.json; } && \
  jq --arg s "<status>" --arg n "<next_step>" \
     '.plan_status = $s | .next_step = $n | .saved_at = (now | todate)' \
     .devflow-state.json > .devflow-state.json.tmp && \
  mv .devflow-state.json.tmp .devflow-state.json
```

Replace `<status>` and `<next_step>` per the table above. Full snapshot (file lists, counts) still refreshed by `hooks/pre-compact.sh` at compaction.

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

`.devflow-run.json` at project root — presence switches pipeline skills to **run mode**: ambiguity → decision flag in `plan.md` `## Decision flags` (see `devflow-run` skill → Step 2), intermediate notify gates do not wait for user.

```json
{
  "active": true,
  "feature": "003_user-profile",
  "from": "implement",
  "until": "test",
  "started_at": "2026-07-17T10:00:00Z"
}
```

Lifecycle:

- Written by `devflow.run` Step 0 — only after explicit user confirmation; no other skill arms run mode
- Deleted by `devflow.run` on every exit path (complete, contract failure, block, handoff)
- Never committed — `devflow.run` appends it to `.gitignore` when present
- Stale marker (found at session start, no run in progress) → `devflow.resume` asks: continue interactively (delete marker) or re-arm `devflow.run`; corrupted → `devflow.recovery`

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
