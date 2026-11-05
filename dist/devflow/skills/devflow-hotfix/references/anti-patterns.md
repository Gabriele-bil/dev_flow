# devflow-hotfix — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Committing code without `task.md` or `plan.md` | Compact specs from real templates first |
| Regression test written green-first | Failing test before fix, every time |
| Scope creep into unrelated refactors | Root cause only; cleanups get their own task |
| Hardcoded `main` / own `gh pr create` | Hand off to `devflow-pr` (base detection, cleanup) |
| Hotfix on auth/payments/security boundary | Full pipeline — those need ship's `security-auditor` |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Write test after fix, it passes, done" | Test never seen failing proves nothing — Prove-It |
| "Hotfix spec can skip Traceability/Branch" | `devflow.backprop`, `devflow.status`, `devflow.pr` read them |
| "No ship review, so skip `verification.md`" | `tested → shipped` is refused without it — it is the hotfix's only gate |
