# devflow-run — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Waiting for user at intermediate step gates while run active | Record the step's notify block; continue chain |
| Silent default without flag entry | Every autonomous decision → `plan.md` `## Decision flags` |
| Looping a failing step beyond ladder budget | `escalation-ladder.md` bounds retries; Level 5 → stop run with stuck-report |
| Leaving `.devflow-run.json` after stop | Delete marker on every exit path — stale marker corrupts next session's mode detection |
| Auto-routing to `devflow.pr` after clean ship | Run never crosses the PR boundary; user runs `devflow.pr` |
| Arming run mode from another skill or mid-conversation | Only Step 0, only after explicit user confirmation |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "User said run unattended, committing saves them a step" | Commit/push/PR never unattended — policy table; `devflow.pr` is a human gate |
| "This ambiguity is too important to just flag" | Blocked run = zero progress overnight. Conservative default + flag; user overrides before PR |
| "This opinable improvement is obviously right, apply it" | No approval channel in run mode. Certain improvements only; rest = flags |
| "Skip beautify to reach tests faster" | Only the `quick` profile skips it; otherwise chain order is fixed and every status boundary written |
| "Marker file is missing but user wanted autonomy earlier" | No marker = interactive rules. Only Step 0 confirmation arms run mode |
