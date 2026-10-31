# devflow-analyze — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| "Traceability close enough" | Untraceable subtasks → silent bugs in `devflow.test` |
| Vague acceptance criteria | `devflow.test` writes from ACs; vague ACs → untestable |
| Skipping analyze ("plan looks fine") | 6-pass structural check; one read catches silent gaps |
| Contradicting accepted ADRs | Plan re-introducing rejected alternative → Critical finding |
| Running analyze mid-implementation | Run before `devflow.implement`; post-impl use `devflow.beautify` |
| Waiving Critical findings without documentation | Document in `plan.md` Open questions |
| Fixing findings in `plan.md` only | Check if root is in `task.md` first |
