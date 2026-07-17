# Pipeline State Machine

Single source of truth for DevFlow statuses and transitions. Cited by `devflow-discovery`, `devflow-status`, `devflow-resume`, `devflow-recovery`, and `hooks/pre-compact.sh`. Do not invent statuses outside this file.

## Where state lives

| Artifact | Field | Written by |
| --- | --- | --- |
| `task.md` | `**Status:**` | `devflow.task`, `devflow.clarify`, `devflow.pr` |
| `plan.md` | `**Status:**` + `[done]`/`[pending]` markers | pipeline skills at step boundaries |
| `.devflow-state.json` | snapshot (feature, plan_status, next_step, progress) | `hooks/pre-compact.sh`, `hooks/post-task-create.sh`, skills via State update snippet |

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

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Inventing a status (`in-review`, `wip`) | Only statuses in this file; new status = edit this file first |
| Skipping a status ("implement + beautify in one go") | Each boundary writes its status — resume and hooks depend on it |
| Editing `.devflow-state.json` to change pipeline position | Edit `plan.md` Status; state file is derived cache |
| Setting `tested` with FAIL verdicts in `verification.md` | FAIL = not tested; fix or backprop first |
