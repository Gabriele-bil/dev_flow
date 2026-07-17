# Status Schema — `devflow.status --json`

Machine-readable pipeline status for CI and scripts. `devflow.status --json` runs the emitter snippet below and outputs the JSON object only — no prose, no dashboard.

## Output object

```json
{
  "schema_version": 1,
  "generated_at": "2026-07-17T10:00:00Z",
  "adapter": "flutter",
  "feature": "003_user-profile",
  "plan_path": "devflow/features/003_user-profile/plan.md",
  "plan_status": "implementing",
  "next_step": "devflow.implement",
  "complexity": "standard",
  "progress": { "done": 4, "pending": 6, "total": 10 },
  "pending_files": ["lib/features/profile/profile_page.dart"],
  "checkpoint_present": true,
  "state_drift": false,
  "health": "healthy"
}
```

| Field | Source | Notes |
| --- | --- | --- |
| `schema_version` | constant `1` | bump on breaking change to this file |
| `generated_at` | emitter run time (UTC ISO-8601) | not `.devflow-state.json` `saved_at` |
| `adapter` | `devflow/config.md` `**Adapter:**` line | `"unknown"` when unparsable |
| `feature`, `plan_path` | latest `devflow/features/*/plan.md` | most recently modified |
| `plan_status` | `plan.md` `**Status:**` (authoritative) | legal values: `state-machine.md` |
| `next_step` | status → step mapping in `state-machine.md` | |
| `complexity` | `plan.md` `**Complexity:**` profile | `"standard"` when tag missing |
| `progress`, `pending_files` | `[done]`/`[pending]` markers in File List | |
| `checkpoint_present` | `.checkpoint.json` existence in feature dir | surviving file = interrupted work |
| `state_drift` | `plan_status` ≠ `.devflow-state.json` `plan_status` | informational — plan.md wins |
| `health` | validation below | `healthy` / `no-pipeline` / `inconsistent` |

## Exit codes

| Exit | `health` | Condition |
| --- | --- | --- |
| 0 | `healthy` | plan exists, status legal, markers consistent |
| 1 | `no-pipeline` | no `devflow/config.md`, or no `devflow/features/*/plan.md` |
| 2 | `inconsistent` | status not in `state-machine.md` tables, or status `implemented`+ with `[pending]` entries remaining |

`state_drift: true` alone does NOT set exit 2 — state file is a derived cache; `plan.md` wins.

## Emitter snippet

Run by `devflow.status` Step 3-JSON. Requires `jq`.

```bash
#!/bin/bash
command -v jq >/dev/null 2>&1 || { echo '{"schema_version":1,"health":"no-pipeline","error":"jq missing"}'; exit 1; }
[ -f devflow/config.md ] || { jq -n '{schema_version:1, health:"no-pipeline"}'; exit 1; }

ADAPTER=$(grep -m1 '^\*\*Adapter:\*\*' devflow/config.md 2>/dev/null | sed 's/^\*\*Adapter:\*\*[[:space:]]*//' | tr -d '\r' | sed 's/[[:space:]]*$//')
[ -z "$ADAPTER" ] && ADAPTER="unknown"

PLAN_FILE=$(find devflow/features -name "plan.md" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
[ -z "$PLAN_FILE" ] && { jq -n --arg a "$ADAPTER" '{schema_version:1, adapter:$a, health:"no-pipeline"}'; exit 1; }

FEATURE=$(echo "$PLAN_FILE" | sed 's|devflow/features/||; s|/plan.md||')
PLAN_STATUS=$(grep -m1 '^\*\*Status:\*\*' "$PLAN_FILE" | sed 's/^\*\*Status:\*\*[[:space:]]*//' | tr -d '\r' | sed 's/[[:space:]]*$//')
COMPLEXITY=$(grep -m1 '^\*\*Complexity:\*\*' "$PLAN_FILE" | grep -oE 'quick|standard|thorough' | head -1)
[ -z "$COMPLEXITY" ] && COMPLEXITY="standard"

DONE=$(grep -cE '^###.*\[done\]' "$PLAN_FILE" 2>/dev/null; true);    DONE=$(echo "$DONE" | tr -d '[:space:]');    [ -z "$DONE" ] && DONE=0
PENDING=$(grep -cE '^###.*\[pending\]' "$PLAN_FILE" 2>/dev/null; true); PENDING=$(echo "$PENDING" | tr -d '[:space:]'); [ -z "$PENDING" ] && PENDING=0
PENDING_JSON=$(grep -E '^###.*\[pending\]' "$PLAN_FILE" 2>/dev/null | grep -oE '`[^`]+`' | tr -d '`' | jq -Rn '[inputs | select(length > 0)]' 2>/dev/null || echo "[]")

# Status → next_step (keep in sync with state-machine.md)
case "$PLAN_STATUS" in
  ready|implementing) NEXT="devflow.implement" ;;
  implemented)        NEXT="devflow.beautify"  ;;
  beautified)         NEXT="devflow.test"      ;;
  tested)             NEXT="devflow.ship"      ;;
  shipped)            NEXT="devflow.pr"        ;;
  pr-opened)          NEXT="devflow.task"      ;;
  blocked)            NEXT="devflow.recovery"  ;;
  *)                  NEXT="unknown"           ;;
esac

HEALTH="healthy"; EXIT=0
[ "$NEXT" = "unknown" ] && { HEALTH="inconsistent"; EXIT=2; }
case "$PLAN_STATUS" in
  implemented|beautified|tested|shipped|pr-opened)
    [ "$PENDING" -gt 0 ] && { HEALTH="inconsistent"; EXIT=2; } ;;
esac

CKPT=false
[ -f "devflow/features/$FEATURE/.checkpoint.json" ] && CKPT=true

DRIFT=false
STATE_STATUS=$(jq -r '.plan_status // empty' .devflow-state.json 2>/dev/null)
[ -n "$STATE_STATUS" ] && [ "$STATE_STATUS" != "$PLAN_STATUS" ] && DRIFT=true

jq -n \
  --arg a "$ADAPTER" --arg f "$FEATURE" --arg p "$PLAN_FILE" \
  --arg s "$PLAN_STATUS" --arg n "$NEXT" --arg c "$COMPLEXITY" --arg h "$HEALTH" \
  --argjson done "$DONE" --argjson pending "$PENDING" --argjson pf "$PENDING_JSON" \
  --argjson ckpt "$CKPT" --argjson drift "$DRIFT" \
  '{schema_version: 1, generated_at: (now | todate), adapter: $a, feature: $f,
    plan_path: $p, plan_status: $s, next_step: $n, complexity: $c,
    progress: {done: $done, pending: $pending, total: ($done + $pending)},
    pending_files: $pf, checkpoint_present: $ckpt, state_drift: $drift, health: $h}'
exit $EXIT
```

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Adding fields without bumping `schema_version` | Additive fields OK at same version; renamed/removed/retyped fields → bump + document |
| Emitting prose around the JSON in `--json` mode | Single JSON object on stdout, nothing else — consumers parse it |
| Reading `.devflow-state.json` as the status source | plan.md is authoritative; state file only feeds `state_drift` |
| Exit 2 on `state_drift` alone | Drift is informational; exit 2 reserved for real corruption |
