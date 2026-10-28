# Plan Anti-Patterns Reference

Full catalog of planning anti-patterns, symptoms, and required fixes.

## Anti-Patterns Catalog

| Anti-Pattern | Fix |
| --- | --- |
| Writing plan without reading `task.md` | Always start with `task.md` |
| File list in layer order (all models → services → UI) | Order by user-visible increment; checkpoint per slice |
| No Traceability row for a subtask | Every subtask → at least one file + criterion |
| File List entry with no Traceability row (gold-plating) | Remove it or map to a subtask; new scope goes through `devflow.task` |
| Open questions with Status `ready` | Leave open; escalate to user; never guess |
| Reuse audit skipped ("implement will figure it out") | Audit in Step 3; document in Architecture decisions |
| New component without checking shared/ | ≥70% coverage rule; extend first |
| Dependencies without explicit ordering | Sort file list; document rationale in Architecture decisions |
| Architecture decisions made during implement | All decisions in `plan.md` before implement |
| Adapter sections omitted | Apply every required section from the adapter plan step file |
| No implementation checkpoints on long plans | ≥2 checkpoints for plans >5 files |
| Complexity score skipped or guessed | Score per `complexity-scoring.md` signals in Step 4d; downstream steps default to `standard` without it |
