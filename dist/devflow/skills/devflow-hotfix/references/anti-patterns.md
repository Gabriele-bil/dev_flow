# devflow-hotfix — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Committing code without `task.md` or `plan.md` | Compact specs from real templates first |
| Skipping regression test or writing it green-first | Failing test before fix, every time |
| Expanding hotfix scope to unrelated refactors | Strictly scoped; separate tasks for cleanups |
| Hardcoded `main` / own `gh pr create` | Hand off to `devflow-pr` (base detection, cleanup) |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Tag after fix — same commit anyway" | Tag before first edit is the rollback point; after-fix tag restores the fix |
| "Write test after fix, it passes, done" | Test never seen failing proves nothing — Prove-It |
| "Hotfix spec can skip Traceability/Branch" | `devflow.backprop`, `devflow.analyze`, `devflow.rollback`, `devflow.pr` read them |
