# Goal-Backward Verification

Four-level verification run by `devflow.test` (Step 6b) after tests pass. Works **backwards from the spec**: start from each acceptance criterion in `task.md`, not from what was implemented. A stubbed function with a passing unit test and clean review sails through forward-looking checks — this catches it.

## The four levels

| Level | Question | How to check |
| --- | --- | --- |
| **1 — Existence** | Do expected files, symbols, routes, migrations exist? | File on disk; symbol defined (grep declaration); route/migration present |
| **2 — Substantive** | Real code, not stubs? | Scan implementing files for stub signals (table below) |
| **3 — Wired** | Reachable in the running app? | Symbol imported/used **outside** its defining file; route registered; provider/middleware applied; UI reachable via navigation. Dead code = not satisfied |
| **4 — Runtime** | Does it behave end-to-end? | Run adapter **Verify (runtime)** command covering the AC (`ADAPTER.md` → **Test → Verify (runtime)**); fallback: integration/e2e targets from **Test → Commands**. No matching target → mark `N/A` |

Levels 1–3 are pure static inspection (grep/read — cheap). Level 4 executes only targets the adapter already defines — run only specs covering the AC under verification, never the full suite again. Visual verification (screenshot diffing, occlusion) is out of scope.

## Level 2 stub signals

| Signal | Example |
| --- | --- |
| Placeholder comments | `// TODO`, `// implement this`, `FIXME`, `HACK` |
| Hardcoded returns | `return true;`, `return [];`, `return "test"` where logic is expected |
| Empty error handling | empty `catch`/`except` block, swallowed error |
| Unimplemented throws | `UnimplementedError`, `NotImplementedException`, `throw new Error("not implemented")` |
| Disabled tests | `skip`, `xit`, `xdescribe`, `@Ignore` on tests covering the AC |
| Placeholder UI | lorem ipsum copy, empty `Container()`, `<div>placeholder</div>` |

## Level 3 rules

- Import from a barrel/re-export file alone does NOT count as wired — find a real call/render site.
- Route handler defined but not registered = not wired.
- Feature flag permanently off = not wired; note the flag in the report.

## Procedure (per AC)

1. Locate implementing file(s) via `plan.md` → **Traceability** table (mandatory — makes this lookup free).
2. Run levels in order; first failing level stops the chain for that AC.
3. Record verdict: **PASS** (all applicable levels pass) · **FAIL** (any of 1–3 fails, or 4 executes and fails) · **PARTIAL** (1–3 pass, 4 is `N/A`).
4. AC with no Traceability row → **FAIL** (missing requirement — candidate for `devflow.backprop`).

## Report template — `verification.md`

Write to `devflow/features/[NNN]_[feature-name]/verification.md`:

```markdown
# Verification - [Feature Name]

**Feature:** [NNN]_[feature-name]
**Date:** [YYYY-MM-DD]
**Result:** PASS | FAIL   (FAIL if any AC verdict is FAIL)

| # | Acceptance criterion | Files (Traceability) | L1 | L2 | L3 | L4 | Verdict |
|---|---------------------|----------------------|----|----|----|----|---------|
| 1 | [criterion] | `path/file.ext` | ✅ | ✅ | ✅ | N/A | PARTIAL |

## Failures
(only if any FAIL)
- **AC [#]** failed **L[N]**: [evidence — file:line, stub signal, missing registration] → [fix pointer]
```

## Gate rule

`devflow.test` sets `plan.md` `**Status:** tested` only when tests pass AND `verification.md` **Result** is not FAIL. `devflow.ship` input contract requires `verification.md` present with zero FAIL verdicts.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Verifying forward from File List ("all files written = done") | Start from each AC; files are evidence, not the goal |
| Counting a passing unit test as Level 3 | Unit test imports the symbol directly; wiring means the app reaches it |
| Marking PARTIAL as PASS in summary | PARTIAL is explicit: runtime unproven; report it as such |
| Skipping verification because review was clean | Review is forward-looking; verification is goal-backward — different failure classes |
