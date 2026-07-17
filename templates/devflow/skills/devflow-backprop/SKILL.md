---
name: devflow-backprop
description: Backpropagates a bug or failing test into the spec — traces failure to its acceptance criterion via traceability, classifies the gap, tightens task.md, adds regression test. Use when a bug found after implement reveals a spec gap.
argument-hint: [bug-description-or-test-path]
---

# Skill: devflow.backprop

Spec backpropagation. A bug that escaped the pipeline means the spec was wrong, not just the code. Fix the spec, add a regression test, log the gap category — the next feature must not repeat it.

## Purpose

Close the loop between runtime failures and `task.md`: trace behavior → acceptance criterion → gap class → tightened criterion + named regression test + logged instinct.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Bug is a pure implementation slip fully covered by an existing AC (AC correct, code wrong) — fix code + regression test directly, no spec change
- Feature has no `task.md`/`plan.md` (pre-DevFlow code) — open a `devflow.task` for the fix instead
- User wants new behavior, not a fixed gap — scope change belongs in `devflow.task`
- Pipeline is stuck or state corrupted — `devflow.recovery`

## Input contract

- [ ] Bug description or failing test provided (via `$ARGUMENTS` or user message)
- [ ] `task.md` and `plan.md` exist for the affected feature (with **Traceability** table)

Any item fails → stop, report which.

## Workflow

### Step 1 — Capture failure

Pin down: observed behavior, expected behavior, trigger conditions. If a failing test path was given, run it and paste the raw failure. No fix attempts yet.

### Step 2 — Trace to spec

1. Identify implementing file(s) from the failure (stack trace, test target).
2. Reverse-lookup in `plan.md` → **Traceability** table: file(s) → subtask → acceptance criterion in `task.md`.
3. Record nearest AC. Behavior covered by no AC at all → note it — that is already the classification signal.

### Step 3 — Classify the gap

Use taxonomy in `references/backprop-patterns.md`:

| Class | Meaning |
| --- | --- |
| **missing criterion** | Behavior belongs to an existing subtask; no AC covered it |
| **incomplete criterion** | An AC exists but is too weak (happy-path only, boundary unstated) |
| **missing requirement** | Whole behavior absent from spec — no subtask, no AC |

Also tag the **gap family** (input validation, concurrency, error handling, integration, state lifecycle, auth) from the same reference.

### Step 4 — Tighten the spec (user approves)

Propose, then apply after approval:

- **missing criterion** → add AC under the existing subtask in `task.md`
- **incomplete criterion** → rewrite the AC: observable, falsifiable, boundary explicit
- **missing requirement** → add subtask + AC; large scope → route to `devflow.task` instead
- Update `plan.md` **Traceability** row(s) for the new/changed AC
- Append entry to `task.md` → `## Notes`: `[YYYY-MM-DD] backprop: [gap class / family] — [1-line summary]`

### Step 5 — Regression test

Name it before writing: `[test file path] :: [test name referencing the AC]`. Test must fail on current code (Prove-It), pass after fix. Write it per active `ADAPTER.md` → **Test** conventions. Code fix itself: trivial → apply now; non-trivial → re-enter `devflow.implement` for affected File List entries (status transition per `@devflow/references/state-machine.md`, user-confirmed). Slice `deps:` annotations present in **File List** → scope re-entry to the affected slice plus downstream slices listing it in `deps`; untouched independent slices stay `[done]`.

### Step 6 — Log the gap (systemic rule)

1. Log instinct via `devflow.learn log`: trigger = gap family, action = the tightened-criterion pattern, domain = `backprop-[family]`.
2. Count existing instincts with same `backprop-[family]` domain. **3+ entries** → propose a standard clarify question: "This project hit [family] gaps [N] times. Add standing question '[proposed question]' to the `devflow.clarify` scan for future features?" Log accepted question as high-confidence instinct (`domain: clarify`).

### Step 7 — Notify

```text
🔁 Backprop complete: [NNN]_[feature-name]

Gap:        [class] / [family]
AC updated: [old → new, or "added"]
Regression: [test file :: test name] — failing before fix: [yes/no]
Fix:        [applied inline | routed to devflow.implement]
Instinct:   [id] logged ([N] total in family[; clarify question proposed])
```

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Just fix the bug, updating the spec is bureaucracy" | Unfixed spec reproduces the gap in the next feature; the fix is 2 lines of task.md |
| "The AC sort of covers it" | AC that didn't catch the bug is by definition incomplete — tighten it |
| "Regression test later, fix now" | Untested fix regresses silently; failing-test-first is the proof the gap is closed |
| "One-off bug, not worth logging" | Families repeat — the 3+ rule only works if every gap is logged |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Rewriting task.md Summary/scope during backprop | Touch only AC, subtask, Traceability, Notes — scope changes go through devflow.task |
| Classifying every gap as "missing requirement" | Check existing subtasks first; most gaps are incomplete criteria |
| Regression test asserting the buggy behavior | Test asserts the tightened AC, not current output |
| Skipping the instinct log | Step 6 is the loop-closer — without it, backprop is just a bugfix |
| Fixing unrelated code "while tracing" | Trace is read-only until Step 4 approval |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md` (Traceability) |
| Reads | `references/backprop-patterns.md`, `@devflow/references/state-machine.md`, `@devflow/adapters/<adapter>/ADAPTER.md` (Test conventions) |
| Writes | `task.md` — AC added/tightened, `## Notes` backprop entry |
| Writes | `plan.md` — Traceability row for changed AC |
| Writes | regression test file per adapter conventions |
| Writes | `.devflow-instincts.yaml` via `devflow.learn log` |
| Related | `devflow-learn` (instinct store), `devflow-clarify` (receives proposed standard questions), `devflow-test` (verification feeds backprop candidates) |
