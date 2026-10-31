# devflow-clarify — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Skipping unresolved markers | `devflow.plan` stops on them; resolve or explicitly waive first |
| Asking dependent questions in one batch, or independent ones one by one | Batch what is independent (≤4 per call); chain what depends on an earlier answer |
| Rewriting `## Summary` to absorb answers | Update target section + `## Clarifications`; preserve original wording |
| Treating clarify as mandatory | Optional; skip if no markers and assumptions are low-risk |
| Absorbing ambiguity into plan instead | Unresolved → silent assumptions → bugs in `devflow.test` |
| Batch-updating `task.md` at Q&A end | Update after each accepted answer |
| Skipping questions without recording them | Record every skip in `## Clarifications` with reason |
| Asking >5 questions | Cap at 5; surface only highest-risk ambiguities |
