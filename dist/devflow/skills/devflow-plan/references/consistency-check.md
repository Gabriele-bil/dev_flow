# Consistency check (plan Step 5b)

Optional read-only pass over `task.md` + `plan.md` + `constitution.md` + active ADRs, run after `plan.md` is written. Replaces the former `devflow.analyze` command. Writes nothing — findings are fixed by editing `plan.md` (or `task.md` when the root cause is there).

## Inputs

1. `task.md` — use cases / subtasks, acceptance criteria
2. `plan.md` — Traceability table, File List, Architecture decisions
3. `constitution.md` — layer ordering, naming conventions
4. `docs/adr/` — only when referenced in `task.md`/`plan.md` or `docs/adr/README.md` exists

Run every pass; never stop at the first failure. Skip `task.md` rows marked `[wont]` / `[retired]` (verify `plan.md` Traceability does not cite them).

## Passes

| Pass | Check | Severity |
| --- | --- | --- |
| **A — Traceability** | Every UC / subtask has a Traceability row with a non-empty file path | Critical |
| **B — AC testability** | Every AC observable + falsifiable: no "works correctly", "is fast", "handles edge cases", no specific-looking vagueness, no internal state ("writes to table X"), single `When` per scenario (`devflow-task/references/bdd-acceptance-criteria.md`) | Required |
| **C — Terminology** | Same concept, same term across `task.md` and `plan.md` | Nit; Required when divergence crosses a domain boundary (entity named differently in Architecture decisions) |
| **D — Constitution** | Every File List path respects `constitution.md` layer ordering + naming | Critical |
| **E — Coverage balance** | No AC with 0 files; no File List entry with 0 Traceability rows | Required |
| **F — ADR alignment** (conditional) | Plan does not re-introduce a rejected alternative or break an accepted ADR constraint | Critical on direct contradiction; Required on deviation without explicit waiver in Architecture decisions |
| **G — Product fidelity** | Literal-vs-intent gap vs `## Goal & Value`; gaps in `UC-1..N` / `AC-1..N` numbering or `[wont]` rows still wired; counters without empty/unavailable state (shows `0`/blank); user-facing copy leaking IDs, field names, stack traces | Required |

## Severity

| Severity | Action |
| --- | --- |
| **Critical** | Fix `plan.md`/`task.md` before `devflow.implement` |
| **Required** | Fix before implement, or waive explicitly in `plan.md` **Open questions** (run mode: `## Decision flags` entry) |
| **Nit** | Optional |

## Report (in response — no file)

```text
## Consistency check — [NNN]_[feature-name]
A Traceability: PASS | [SEVERITY] [finding] → [one-line fix]
B AC testability: …
C Terminology: …
D Constitution: …
E Coverage balance: …
F ADR alignment: PASS | n/a | …
G Product fidelity: …
Blockers: [N] (Critical + Required) — [fix before devflow.implement | none]
```

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Waiving Critical without documentation | Fix it — Critical is never waived |
| Fixing findings in `plan.md` only | Check whether the root is in `task.md` first |
| Writing a report file | Report lives in the response only |
