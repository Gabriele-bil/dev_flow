# devflow-recovery — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Auto-fix state without diagnosis / re-run from step 1 | Read `.devflow-state.json` + last 20 observe entries first; resume from last `[done]` marker. |
| Auto-execute nuclear reset without user confirmation | Present all options; wait for explicit choice. Nuclear destroys traceability. |
| Use recovery for normal pipeline progression | `devflow-status` first; recovery only when status shows corruption or `blocked`. |
| Resyncing only the state file for a `blocked` feature | `plan.md` is authoritative — Category G resets `plan.md` Status (user-confirmed), then state |
| Overwriting `.devflow-state.json` with a fresh object | Merge via snippet — hook/other keys survive |
| Ignore `.devflow-observe.jsonl` during diagnosis | Observe log shows exact tool calls before failure — always check it. |
