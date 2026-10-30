# devflow-rollback — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Running `git reset --hard` without updating `plan.md` | Always sync `plan.md` status and `.devflow-state.json` so the pipeline knows where it is. |
| Deleting `task.md` or `plan.md` during rollback | Rollback only touches code files and status markers; specifications are preserved. |
| Rolling back committed PRs | Rollback is strictly for local in-progress feature branches before `devflow.pr`. |
