# devflow-backprop — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Rewriting task.md Summary/scope during backprop | Touch only AC, subtask, Traceability, Notes — scope changes go through devflow.task |
| Classifying every gap as "missing requirement" | Check existing subtasks first; most gaps are incomplete criteria |
| Regression test asserting the buggy behavior | Test asserts the tightened AC, not current output |
| Skipping the instinct log | Step 6 is the loop-closer — without it, backprop is a plain bugfix |
| Fixing unrelated code "while tracing" | Trace is read-only until Step 4 approval |

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Just fix the bug, updating the spec is bureaucracy" | Unfixed spec reproduces the gap in the next feature; the fix is 2 lines of task.md |
| "The AC sort of covers it" | AC that didn't catch the bug is by definition incomplete — tighten it |
| "Regression test later, fix now" | Untested fix regresses silently; failing-test-first is the proof the gap is closed |
| "One-off bug, not worth logging" | Families repeat — the 3+ rule only works if every gap is logged |
