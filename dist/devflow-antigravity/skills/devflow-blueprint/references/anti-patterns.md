# devflow-blueprint — anti-patterns and rationalizations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Skip dependency graph — "deps obvious" | Implicit deps → merge conflicts. Always make explicit. |
| Context brief not self-contained ("see step [NNN]") | Fresh agent in new session cannot proceed. Brief = files, contracts, constraints, full context. |
| Skip/rush adversarial review | Wrong parallelization caught only during implement. Always run the gate. |
| Mark all steps `parallel-safe: yes` by default | Concurrent edits → conflicts. Default `no`; prove `yes` only when no shared files. |
| Edit steps after adversarial review without re-marking `draft` | Review gate bypassed. Mark `draft` → re-run adversarial → re-approve. |
| Use blueprint for single-PR scope | Use `devflow.task` → `devflow.plan` directly. |
| Step has no acceptance criteria | `devflow.implement` cannot prove completion. |
| Step title is a layer ("add tests") not outcome increment | Layer-shaped → big-bang delivery. Reframe as increments. |
| Two parallel-safe steps touch the same file / graph is straight line / missing transitive edges | Concurrent edits, wrong ordering, missed parallelism. Default `parallel-safe: no`; include all transitive deps; review straight-line graphs for parallel workstreams. |
