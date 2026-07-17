# Escalation Ladder

Unified failure-handling ladder for `devflow.implement`, `devflow.beautify`, `devflow.test`.
Replaces per-skill "retry 3× then stop" clauses. Bounded at every level — no infinite loops, no silent stalls.

## Ladder

| Level | Trigger | Action |
| --- | --- | --- |
| **1 — Bounded retry** | Command or test fails | Max **3 attempts**. Each attempt must change something material (fix, mock setup, root cause) — never rerun unchanged |
| **2 — Debug mode** | 3 failed attempts | Stop patching. Read **full** error output. Form ONE explicit hypothesis. Design minimal probe (log line, isolated run, single-file test). Max **2 hypotheses** |
| **3 — Re-approach** | 2 failed hypotheses | Reread `task.md` + `plan.md`. Question the plan step itself — wrong file order, missing dependency, flawed decision. Propose plan deviation; log in `plan.md` → `## Implementation deviations` |
| **4 — Decompose** | Re-approach fails | Split current slice into smaller sub-steps in `plan.md` **File List** (user approves). Retry smallest step first |
| **5 — Block** | Identical error text across 2 consecutive rounds, or Level 4 exhausted | Set `plan.md` `**Status:** blocked`. Emit stuck-report (below). Hand to user. Never falsify progress |

## Level rules

- Levels are strictly ordered — no skipping down (retry #7 disguised as "debug"), no skipping up (blocking before retries spent).
- Attempt counter resets per distinct failure, not per session. Same error after "fix" = same failure, counter continues.
- "Identical error text" = same error class + message; line numbers may differ.
- Level 3 deviations require user visibility: state old approach → new approach → reason.

## Stuck-report format (Level 5)

```text
🛑 BLOCKED: [step] on [feature]

Failure:    [command/test + exact error, 1-3 lines]
Attempts:   [N] retries, [N] hypotheses tested
Tried:      [bullet per approach + why it failed]
Suspicion:  [best current theory, marked as unverified]
Plan state: [done]/[pending] counts; deviations logged: [yes/no]

Options:
  1. [most promising manual intervention]
  2. [alternative — e.g. re-plan the slice]
  3. Waive this step with documented exception
```

## Cross-model rescue (optional variant)

Hosts supporting per-agent model switching: at Level 2, one hypothesis may come from a fresh agent on a different model (fresh perspective, no accumulated bias). Counts against the 2-hypothesis budget. Skip on hosts without model routing.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Retry #4+ with cosmetic variations | Level 1 caps at 3; move to debug mode |
| "Debugging" by adding speculative fixes | Level 2 = one hypothesis, one minimal probe |
| Deleting failing test to unblock | Never. Failing test is signal; escalate the ladder |
| Blocking without stuck-report | Report format is mandatory — user needs state to help |
| Same error twice, still retrying | Two identical rounds = Level 5, stop |
