---
name: backprop
description: Backpropagates a bug or failing test into the spec — traces failure to its acceptance criterion via traceability, classifies the gap, tightens task.md, adds regression test. Use when a bug found after implement reveals a spec gap.
argument-hint: "[bug-description-or-test-path]"
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts|contexts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

# Skill: devflow.backprop

**Arguments:** `$ARGUMENTS` — empty → ask the user for the observed failure before Step 1.

Spec backpropagation. A bug that escaped the pipeline means the spec was wrong, not only the code. Fix the spec, add a regression test, log the gap category — the next feature must not repeat it.

## Purpose

Close the loop between runtime failures and `task.md`: trace behavior → acceptance criterion → gap class → tightened criterion + named regression test + logged instinct.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

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

Name it before writing: `[test file path] :: [test name referencing the AC]`. Test must fail on current code (Prove-It), pass after fix. Write it per the adapter test step file (`${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/steps/test.md`; legacy: `ADAPTER.md` → **Test**) conventions. Code fix itself: trivial → apply now; non-trivial → `devflow.implement --fix <affected File List entries>` re-entry mode (backward transition per `${CLAUDE_PLUGIN_ROOT}/references/state-machine.md`, user-confirmed), then `devflow.beautify` → `devflow.test` again. Trivial inline fix on a plan past `implemented` → still re-run `devflow.test` (regenerates `verification.md`) before ship. Slice `deps:` annotations present in **File List** → scope re-entry to the affected slice plus downstream slices listing it in `deps`; untouched independent slices stay `[done]`.

### Step 6 — Log the gap (Rigor systemic rule)

1. Derive a structured `cause_key` (`gap:<family>:<short-slug>` or `test:<file>::<title>`). Log instinct via `devflow.learn log`: trigger = gap family + `cause_key`, action = the tightened-criterion pattern, domain = `backprop-[family]`.
2. **Rigor repeat check (2+ occurrences or `--never-again`):** Count existing instincts with the same `cause_key` or `backprop-[family]` domain. On **2+ entries** (or immediately if user says "never again"):
   - Propose an executable `check_cmd` (with optional `ratchet_max` count for legacy code) that fails on the pre-fix state (*Red*) and passes on the fixed state (*Green*), OR a standing `devflow.clarify` question if not statically checkable.
   - Once approved by user, promote to `.devflow-instincts.shared.yaml` (`devflow.learn promote`).

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
| Skipping the instinct log | Step 6 is the loop-closer — without it, backprop is a plain bugfix |
| Fixing unrelated code "while tracing" | Trace is read-only until Step 4 approval |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md` (Traceability) |
| Reads | `references/backprop-patterns.md`, `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/steps/test.md` (Test conventions) |
| Writes | `task.md` — AC added/tightened, `## Notes` backprop entry |
| Writes | `plan.md` — Traceability row for changed AC |
| Writes | regression test file per adapter conventions |
| Writes | `.devflow-instincts.yaml` via `devflow.learn log` |
| Related | `devflow-learn` (instinct store), `devflow-clarify` (receives proposed standard questions), `devflow-test` (verification feeds backprop candidates) |
