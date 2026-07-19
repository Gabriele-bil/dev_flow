---
name: devflow-test
description: Writes/runs unit+integration tests via adapter targets, bounded retries. Use when user runs devflow.test, validates feature after beautify, or fifth pipeline step.
argument-hint: [optional-plan-path]
disable-model-invocation: true
---

# Skill: devflow.test

## Quick Start

Run `/devflow.test [optional plan path]`.

- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, resolve the latest `devflow/features/*/plan.md`

## Purpose

Write/run tests for current feature per active adapter **Test** section (unit/integration targets per adapter). Fifth DevFlow step.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- The adapter’s analyze/typecheck command still reports errors — tests cannot be meaningful until the code compiles cleanly
- Neither `devflow.implement` nor `devflow.beautify` has run for this feature — there is no code to test
- The goal is to test a pre-existing feature not modified in this DevFlow run — open a separate task for that

## Input contract

Before proceeding, verify:

- [ ] `devflow.implement` (and optionally `devflow.beautify`) has run for this feature
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] Active adapter analyze/typecheck reports no errors

If any item fails → stop, report which check failed, do not write test files.

## Input

Files from `devflow.implement` + `devflow.beautify` + `devflow/features/[NNN]_[feature-name]/plan.md` — if no arg, resolve latest `devflow/features/*/plan.md`.

## Workflow

### Step 0 - Resolve adapter

Read `@devflow/config.md`, then `@devflow/adapters/<adapter>/ADAPTER.md` (core) plus `@devflow/adapters/<adapter>/steps/test.md`. Legacy adapters without `steps/`: the **Test** section lives in `ADAPTER.md`. The test step file defines placement, frameworks, coverage expectations, and shell commands — follow it exactly for this run.

### Step 1 - Read docs

Always read before starting:

- `constitution.md`
- `registry.md`

### Step 2 - Scope

**Depth profile:** read `**Complexity:**` from `plan.md` (per `@devflow/references/complexity-scoring.md`; missing → `standard`). `quick` → happy path + 1 regression case per AC; skip exhaustive error-path matrix. `standard` → happy path + ≥1 error path per public surface. `thorough` → standard + edge cases per `@devflow/references/testing-patterns.md`.

Test only files belonging to the current feature.

- Do not write tests for shared/core files or pre-existing code unless they were modified in this DevFlow run
- Keep test additions focused on files touched by current feature implementation

### Step 2b - Coverage gap check

**Beyonce Rule:** if behavior matters enough to keep, it deserves a test. No "too simple to test" exceptions.

Before writing any test, enumerate coverage gaps:

1. List all public functions, classes, and state methods in feature files from the implement summary
2. For each: note whether a happy-path test case and at least one error/edge-path case exist or will be written
3. Explicitly name any public surface with no test coverage — do not silently skip

Report gap inventory before writing tests so user can see what will and will not be covered. If adapter defines `test-coverage-threshold`, flag any public surface that would cause feature to fall below it.

### Step 3 through 6 - Author and run tests

Read `task.md` **Acceptance criteria** section first — derive at least one test case per criterion. Then use `plan.md`, the coverage gap inventory from Step 2b, and the implement/beautify summaries:

1. **Placement** — mirror source layout and integration paths per the adapter test step file.
2. **Unit tests** — cover models, state, domain rules, and UI assertions per the adapter test step file (load any technology skills it references).
3. **Integration tests** — target user flows from `task.md` per the adapter test step file (targets/environments and execution order).
4. **Execute** — run the exact commands from the adapter test step file; paste raw stdout/stderr in the Step 7 report.

**Output discipline (intermediate runs):** retry loops and analysis runs follow `@devflow/references/token-economy.md` → **Derive, don't dump** — filter at source, quote decisive failure lines, report delta on re-runs. Step 7 report still pastes mandated raw evidence.

Failure handling:

- Max 3 attempts per failing test
- Attempt 1: analyze failure output and fix the test or implementation
- Attempt 2: verify mocks and dependencies are correctly set up
- Attempt 3: isolate and fix root cause
- After each failed attempt: append error + what was tried to `.checkpoint.json` `errors_tried` per `@devflow/references/state-machine.md` → **Checkpoint file** — resume/recovery skip already-tried fixes
- After 3 attempts: escalate per `@devflow/references/escalation-ladder.md` — Level 2 debug mode (one hypothesis, minimal probe), Level 3 re-approach (question the plan step), Level 5 block with stuck-report. Never mark a failing test as passing
- Context pressure (host compaction warning, long retry session) → write `devflow/features/[NNN]_[feature-name]/handoff.md` per `@devflow/references/state-machine.md` → **Handoff file**, stop, tell user: restart session + `devflow.resume`

### Step 6b - Goal-backward verification

After all tests pass, verify **backwards from the spec** per `@devflow/references/verification-levels.md`:

1. For each acceptance criterion in `task.md`: locate implementing file(s) via `plan.md` → **Traceability** table.
2. Run the four levels — existence, substantive (no stubs), wired (reachable, not dead code), runtime (adapter test step file → **Verify (runtime)** target when defined; fallback: integration targets from **Test → Commands**; neither → `N/A`). Depth per profile: `quick` → levels 1–3; `standard` → levels 1–3 + level 4 when adapter defines targets; `thorough` → level 4 mandatory (no adapter target → verdict PARTIAL with note).
3. Write `devflow/features/[NNN]_[feature-name]/verification.md` using the report template in the reference.
4. Any **FAIL** verdict → do NOT set status `tested`. Implementation gap → fix (re-enter escalation ladder at Level 1) or report. Spec gap (AC missing/too weak) → suggest `devflow.backprop`.

Passing tests do not skip this step — tests prove behavior forward; verification proves every AC satisfied, wired, reachable.

### Step 7 - Notify user

If tests pass AND `verification.md` **Result** is not FAIL: set `plan.md` `**Status:** tested`; refresh `.devflow-state.json` per `@devflow/references/state-machine.md` → **State update snippet**.

Include actual command output. Do NOT report "all tests passed" without raw evidence.

```text
✅ Tests complete: [type]/[NNN]-[feature-name]

### Unit tests
[N] passed · [N] failed · [N] skipped

Output:
```

[paste actual unit test command output here]

```text

### Integration - Target 1
[N] passed · [N] failed

Output:
```

[paste actual integration test output here]

```text

### Integration - Target 2
[N] passed · [N] failed

Output:
```

[paste actual integration test output here]

```text

### Verification (goal-backward)
Result: [PASS | FAIL | PARTIAL] — [N]/[N] ACs verified
Report: devflow/features/[NNN]_[feature-name]/verification.md
[FAIL verdicts listed here with level + evidence]

[-- Failures --]
(shown only if any test failed after 3 attempts)

#### [test file path]
- Test: [test name]
- Error: [error message]
- Attempts: 3/3 - unresolved
- Notes: [what was tried]

---

All tests passing and verification clean? Choose how to continue:
1. Run ship gate (multi-agent review) -> devflow.ship
2. Run full project test suite before opening PR -> devflow.pr
3. Skip full suite and open PR directly -> devflow.pr
```

Wait for user choice before continuing. **Run mode** (`.devflow-run.json` present): emit the block but do not wait — control returns to `devflow.run` (ship stays human).

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Writing tests after PR is open | Tests are a pre-condition for `devflow.pr` |
| Manual-only testing | Automated tests required for PR checklist |
| Skipping trivial files | A trivial test beats no test; untestable → document why |
| Skipping integration tests | They cover user flows unit tests can't |
| Marking failing tests as passing after 3 retries | Stop and report; never falsify the summary |
| Testing implementation internals | Test inputs → outputs; mock only system boundaries |
| 100% coverage with no assertions | Every test must assert at least one specific output |
| Flaky test fixed with `retry(3)` | Fix root cause; use deterministic setup |
| Happy-path-only tests | ≥1 error path per public function (`standard`+ profiles; `quick` = happy + regression per AC) |
| Pasting full output of every retry attempt | Decisive lines only during retries; raw evidence in Step 7 report (`token-economy.md`) |
| Skipping `testing-patterns.md` for novel scenarios | Read `@devflow/references/testing-patterns.md` first |
| Skipping verification because tests pass | Tests are forward-looking; Step 6b proves each AC exists, is real, is wired |
| Setting `tested` with FAIL verdicts in verification.md | FAIL = not tested; fix or route to `devflow.backprop` |

## I/O Reference

| | |
| --- | --- |
| Reads | files from `devflow.implement` / `devflow.beautify` summary |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md`, `registry.md`, `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` (core) + `steps/test.md` |
| Reads | `@devflow/references/verification-levels.md` (Step 6b), `@devflow/references/escalation-ladder.md` (failure handling), `@devflow/references/state-machine.md` (status), `@devflow/references/complexity-scoring.md` (depth profile), `@devflow/references/token-economy.md` (output discipline) |
| Reads (conditional) | `.devflow-run.json` (existence — run-mode switch) |
| Reads (optional) | `@devflow/references/testing-patterns.md` — stack-agnostic patterns reference |
| Writes | Test output paths per the adapter test step file |
| Writes | `devflow/features/[NNN]_[feature-name]/verification.md` — per-AC verdict table |
| Writes | `devflow/features/[NNN]_[feature-name]/.checkpoint.json` — `errors_tried` on retry loops (state-machine.md → Checkpoint file) |
| Writes (conditional) | `devflow/features/[NNN]_[feature-name]/handoff.md` — on context pressure (state-machine.md → Handoff file) |
| Writes | `plan.md` — `**Status:** tested` (only when tests pass + verification has no FAIL) |
| Next step | `devflow.ship` (or `devflow.pr` directly for solo quick changes) |
