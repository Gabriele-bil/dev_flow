# devflow-auto — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Asking the user mid-chain | Collect idea/app/stale-marker decisions before Step 0 |
| Re-stating run-mode rules per step | `$HOME/.gemini/antigravity-cli/plugins/devflow/references/run-mode.md` is the contract — cite, don't copy |
| Silent defaults | Every autonomous choice → `## Decision flags` → PR body |
| Leaving `.devflow-run.json` after exit | Disarm on every exit path |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Idea is ambiguous — pause and ask" | Inputs needing the user are collected before arming; afterwards default + flag |
| "Analyze/ship Required finding — stop" | Only major discrepancies stop auto; Required → fix loop / waiver flag → PR |
| "Constitution violation is minor here" | Constitution Gate violations always hard-stop |
