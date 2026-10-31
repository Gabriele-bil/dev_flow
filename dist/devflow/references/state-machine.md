# Pipeline State Machine

Single source of truth for DevFlow statuses and transitions. Cited by `references/orientation.md`, `devflow-status`, `devflow-resume`, `devflow-recovery`, and `hooks/pre-compact.sh`. Do not invent statuses outside this file.

## Where state lives

| Artifact | Field | Written by |
| --- | --- | --- |
| `task.md` | `**Status:**` | `devflow.task`, `devflow.clarify`, `devflow.pr` |
| `plan.md` | `**Status:**` + `[done]`/`[pending]` markers | pipeline skills at step boundaries |
| `docs/adr/ADR-NNN-[title].md` | `**Status:**` (Accepted/Proposed) | `devflow.discover` |
| `.devflow-state.json` | derived cache — schema in **State file schema** below | `hooks/pre-compact.sh`, `hooks/post-task-create.sh`, skills via **Writing state** |
| `.devflow-observe-state.json` | hook counters (tool calls, session id, turn timing) | hooks only — skills never read or write it |
| `devflow/features/[NNN]_[name]/.checkpoint.json` | working context (step, slice, decisions, errors_tried) | `devflow.implement` (slice boundaries), `devflow.test` (retry loops); deleted by `devflow.pr` |
| `.devflow-run.json` | autonomous-run marker (feature, from, until) | `devflow.run` Step 0 or `devflow.auto` Step 0 (`devflow-state.sh run arm`); deleted at every run exit |
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
| `plan_path` | string | snapshot by `hooks/pre-compact.sh` — workspace-relative `plan.md` |
| `done_files` / `pending_files` | string[] | snapshot by `hooks/pre-compact.sh` — File List paths per marker; read by `devflow.resume` |

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

Script form (steps 1–3): `bash "@devflow/scripts/devflow-state.sh" resolve [argument]` — prints `NNN_name`; exit 1 → step 4.

## task.md statuses

```text
draft → clarified → done
draft → done          (clarify skipped)
```

## plan.md statuses

| Status | Meaning | Set by | next_step |
| --- | --- | --- | --- |
| `ready` | Plan approved, not started | `devflow.plan` Step 5 | `devflow.implement` |
| `implementing` | Implement in progress (first pass or `--fix` re-entry) | `devflow.implement` entry (Step 4) / re-entry mode | `devflow.implement` (resume) |
| `implemented` | All File List entries `[done]` | `devflow.implement` exit (Step 8) | `devflow.beautify` (`quick` profile: `devflow.test`) |
| `beautified` | Multi-axis review applied | `devflow.beautify` exit (Step 6) | `devflow.test` |
| `tested` | Tests pass + `verification.md` has no FAIL | `devflow.test` exit (Step 7) | `devflow.ship` |
| `shipped` | Ship gate passed | `devflow.ship` Step 5 | `devflow.pr` |
| `pr-opened` | PR open toward main | `devflow.pr` Step 6 | — (pipeline complete) |
| `blocked` | Escalation ladder Level 5 | any skill per `references/escalation-ladder.md` | `devflow.recovery` |

## Legal transitions

```text
ready → implementing → implemented → beautified → tested → shipped → pr-opened
hotfix fast-track and `quick` profile: ready → implementing → implemented → tested → shipped → pr-opened (beautify skipped)
any active status → blocked          (escalation ladder Level 5)
blocked → <pre-block status> | ready  (devflow.recovery, user-confirmed plan.md reset)
implemented | beautified | tested | shipped → implementing   (devflow.implement --fix re-entry)
tested → shipped requires verification.md with zero FAIL verdicts
```

Backward transitions — always written to `plan.md`, never silent:

- `implementing`/`implemented` → `ready`, `beautified` → `implemented` — `devflow.rollback`, user-confirmed
- `implemented`+ → `implementing` — `devflow.implement --fix` re-entry. Callers: `devflow.ship` fix loop (user chose fix, or run-mode grader loop), `devflow.backprop` Step 5 (user-confirmed), `devflow.recovery` (user-confirmed). Re-entry then walks forward again: `implemented → beautified → tested` — no step skipped, `verification.md` regenerated
- `blocked` → resume status — `devflow.recovery` Category G, user-confirmed

## Writing state

Skills never edit `**Status:**` lines or state JSON by hand — `scripts/devflow-state.sh` writes the markdown and merges the cache in one call, identical on both hosts. Run from the project root; `[F]` = feature argument (omitted → **Active feature resolution**):

| Command | Effect |
| --- | --- |
| `bash "@devflow/scripts/devflow-state.sh" set plan <status> [F]` | `plan.md` `**Status:**` + cache (`plan_status`, `next_step`, `progress`, `branch`, `app`, `next_feature_number`). Refuses (exit 2) an illegal transition, and `tested`/`shipped` without `verification.md` or with Result FAIL |
| `bash "@devflow/scripts/devflow-state.sh" set task <status> [F]` | same for `task.md` (`task_status`) |
| `… set plan <status> [F] --force` | user-confirmed backward reset outside **Legal transitions** (`devflow.recovery`, re-plan) |
| `bash "@devflow/scripts/devflow-state.sh" mark-done <path> [F]` | File List entry `[pending]` → `[done]`, progress refreshed |
| `bash "@devflow/scripts/devflow-state.sh" sync [F]` | rebuild the cache from `plan.md`/`task.md` (after writing a new `task.md`/`plan.md`, after recovery) |
| `bash "@devflow/scripts/devflow-state.sh" status [F]` | one line: statuses, next step, progress |

Merge, never overwrite: unknown keys preserved, legacy `active_feature` dropped. No `jq` → markdown still written, cache skipped. Corrupt cache → `devflow.recovery`. Full snapshot (file lists) still refreshed by `hooks/pre-compact.sh` at compaction.

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

Write it with `bash "@devflow/scripts/devflow-state.sh" checkpoint [F] --step <step> --slice "<slice>" --decision "<d>" --constraint "<c>" --error "<error tried>"` (each array flag repeatable). Arrays are appended, never replaced; `step`/`slice` only when passed. Skipped when `jq` is missing.

## Run marker (autonomous mode)

`.devflow-run.json` at project root — presence switches pipeline skills to **run mode**: behavior contract (autonomy policy, decision flags, discrepancy classes, disarm) in `@devflow/references/run-mode.md`. This section owns the file schema only.

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

- Written by `devflow.run` Step 0 (after user confirmation) or `devflow.auto` Step 0 (immediately on execution) with `devflow-state.sh run arm --orchestrator <o> --from <x> --until <y> [--feature F]`; no other skill arms run mode. `run arm` refuses a stale marker (exit 2), adds the file to `.gitignore`
- Deleted by the owning orchestrator (`devflow.run` or `devflow.auto`) on every exit path (complete, contract failure, block, handoff) — `devflow-state.sh run disarm`; `run feature <NNN_name>` sets `feature` after `devflow.auto`'s task step; `run status` prints it
- Never committed — the arming orchestrator appends it to `.gitignore` when present
- Stale marker (found at session start, no run in progress) → `devflow.resume` asks: continue interactively (delete marker) or re-arm the orchestrator named in `from`/`until` (`devflow.run` or `devflow.auto`); corrupted → `devflow.recovery`

Optional fields, read by `devflow-ship` Step 4b (autonomous grader loop):

- `ship_grader_iterations` — max auto-resend cycles for a Required-only (zero Critical) Ship Gate verdict before surfacing the report instead of looping again. Absent → default 2.
- `ship_grader_iteration_count` — running counter for the current feature's ship gate, incremented by `devflow.ship` on each auto-resend (`devflow-state.sh run bump`, exit 3 at the cap), reset to 0 whenever `devflow.run` re-arms the marker for a new `from`/`until` span. Critical findings ignore this counter entirely — they always hard-stop regardless of iterations remaining.

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
| Editing `.devflow-state.json` or `**Status:**` by hand | `devflow-state.sh set`; state file is derived cache |
| Setting `tested` with FAIL verdicts in `verification.md` | FAIL = not tested; fix or backprop first |
| Committing `.checkpoint.json` | `devflow.pr` deletes it before staging; checkpoint is session context, not project history |
| Treating a stale `.devflow-run.json` as active autonomy | Run mode dies with its session; resume asks before re-arming |
| Writing handoff.md as a log dump | 4 sections, short — next session needs orientation, not transcript |
| Rewriting checkpoint wholesale each slice (losing prior decisions) | `devflow-state.sh checkpoint` appends; never write the file by hand |
