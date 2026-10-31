# devflow-resume — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Resuming from memory of previous session | Read `.devflow-state.json` + `plan.md` fresh at invocation |
| Repairing corrupted state inline | Resume routes; `devflow.recovery` repairs — separate concerns |
| Skipping user confirmation on resume position | Always confirm Step 3 — cheapest wrong-direction insurance |
| Re-running completed pipeline steps "to be safe" | Statuses per `state-machine.md` are authoritative; enter at `next_step` only |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "State file looks fine, skip the cross-check" | State file is a cache written at compaction — plan.md may have moved since. Cross-check is 2 greps |
| "Faster to re-implement the done files, they're small" | Re-implementing `[done]` work destroys prior review/fixes and wastes the session |
| "Position is obvious, no need to confirm with user" | User may have edited files outside DevFlow between sessions — confirmation catches it |
