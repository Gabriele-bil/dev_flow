---
name: devflow-test
description: Writes/runs unit+integration tests via adapter targets, bounded retries. Use when user runs devflow.test, validates feature after beautify, or fifth pipeline step.
argument-hint: "[optional-plan-path] [--changed <files>]"
disable-model-invocation: true
---


# Skill: devflow.test

## Quick Start

Run `/devflow-test [optional plan path]`.

- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, resolve feature with `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask)

## Purpose

Write/run tests for current feature per active adapter **Test** section (unit/integration targets per adapter). Fifth DevFlow step.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- The adapter’s analyze/typecheck command still reports errors — tests cannot be meaningful until the code compiles cleanly
- Neither `devflow.implement` nor `devflow.beautify` has run for this feature — there is no code to test
- The goal is to test a pre-existing feature not modified in this DevFlow run — open a separate task for that

## Input contract

Before proceeding, verify:

- [ ] `devflow.implement` (and optionally `devflow.beautify`) has run for this feature
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] Analyze clean: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/verify-stamp.sh" run analyze -- <adapter analyze cmd>` exits 0 (skipped while beautify's stamp is fresh)

If any item fails → stop, report which check failed, do not write test files.

## Input

Files from `devflow.implement` + `devflow.beautify` + `devflow/features/[NNN]_[feature-name]/plan.md` — if no arg, resolve feature with `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask).

## Workflow

### Step 0 - Resolve adapter

Resolve adapter, adapter root, and app working directory per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md` (reads `plan.md`'s `**App:**` field in monorepo mode). Then read `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/ADAPTER.md` (core) plus `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/steps/test.md`. The test step file defines placement, frameworks, coverage expectations, and shell commands — follow it exactly for this run (monorepo: run test commands from the resolved app's working directory).

### Step 1 - Read docs

Read before writing tests:

- `constitution.md` — test naming, file placement and layering rules the new tests must follow
- `registry.md` — existing test helpers, fixtures and mocks to reuse instead of re-creating

### Step 2 - Scope

**Depth profile:** read `**Complexity:**` from `plan.md` (per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/complexity-scoring.md`; missing → `standard`). `quick` → happy path + 1 regression case per AC; skip exhaustive error-path matrix. `standard` → happy path + ≥1 error path per public surface. `thorough` → standard + edge cases per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/testing-patterns.md`.

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
3. **Integration & E2E tests** — target user flows from `task.md` per the adapter test step file:
   - Detect platform: Web (`nextjs`, `angular`) vs Mobile (`flutter`).
   - Web: write/execute Playwright specs or drive browser runner.
   - Mobile: write/execute Maestro flows (`.maestro/`) or Flutter `integration_test` on emulator/device.
   - Verify clean state transitions, absence of crashes or unhandled runtime errors, and report results.
4. **Execute** — run the exact commands from the adapter test step file through the stamp: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/verify-stamp.sh" run test -- <cmd>` for the whole unit suite, `test:<scope>` for a subset (never reused as the full suite), `e2e[:<scope>]` for integration/E2E targets (monorepo: `--cwd`, `@<app>`). The result line carries passed/failed/skipped counts and the log path; a failure prints its decisive lines. The full output stays in the log (`.devflow-verify/<name>.log`) — the evidence of record.

**Output discipline:** retry loops and analysis runs follow `$HOME/.gemini/antigravity-cli/plugins/devflow/references/token-economy.md` → **Derive, don't dump** — quote decisive failure lines from the log, report delta on re-runs. Step 7 reports the stamp lines, never pasted output.

Failure handling:

- Max 3 attempts per failing test
- Attempt 1: analyze failure output and fix the test or implementation (if failure is in an untouched module or intermittent, run the **Paired Control** isolation check per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/testing-patterns.md` before patching)
- Attempt 2: verify mocks and dependencies are correctly set up
- Attempt 3: isolate and fix root cause
- After each failed attempt: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" checkpoint --step devflow.test --error "<error> — <what was tried>"` — resume/recovery skip already-tried fixes
- After 3 attempts: escalate per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/escalation-ladder.md` — Level 2 debug mode (one hypothesis, minimal probe), Level 3 re-approach (question the plan step), Level 5 block with stuck-report. Never mark a failing test as passing
- Context pressure (host compaction warning, long retry session) → write `devflow/features/[NNN]_[feature-name]/handoff.md` per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/state-machine.md` → **Handoff file**, stop, tell user: restart session + `devflow.resume`

### Step 6b - Goal-backward verification

**`--changed <files>`** (ship fix loop, `quick`/`standard`): re-verify only ACs whose **Traceability** files intersect the list; copy the other rows from the existing `verification.md` unchanged and note `carried over` in their evidence. No `verification.md` yet, or `thorough` → full verification.

After all tests pass, verify **backwards from the spec** per `$HOME/.gemini/antigravity-cli/plugins/devflow/references/verification-levels.md`:

1. For each acceptance criterion in `task.md`: locate implementing file(s) via `plan.md` → **Traceability** table.
2. Run the verification levels:
   - **Level 1 (Existence)**: file on disk, symbol defined, route present.
   - **Level 2 (Substantive)**: no stubs, placeholder comments, or hardcoded returns.
   - **Level 3 (Wired)**: reachable in app flow, registered route/provider, not dead code.
   - **Level 4a (Runtime CLI/API)**: execute adapter `Verify (runtime)` target or integration spec.
   - **Level 4b (UI / Browser & Mobile Workflow)**: Web/UI adapters (`nextjs`, `angular`) and Mobile (`flutter`): run Playwright/e2e target, Maestro flow, or browser/device agent flow to verify mounting, DOM/widget presence, critical interactions, clean state transitions, and zero unhandled crash or console errors.
   - Depth per profile: `quick` → L1–L3; `standard` → L1–L3 + L4 targets when defined + clause pinning (`file:line`); `thorough` → L4 mandatory (missing target → PARTIAL) + break-it probe & canonical edges (`verification-levels.md`).
3. Write `devflow/features/[NNN]_[feature-name]/verification.md` using the template in `verification-levels.md` (including `Pinned Assertion (file:line)` per AC).
4. Any **FAIL** verdict → do NOT set status `tested`. Implementation gap → fix (re-enter escalation ladder at Level 1) or report. Spec gap (AC missing/too weak) → suggest `devflow.backprop`.

Passing tests do not skip this step — tests prove behavior forward; verification proves every AC satisfied, wired, reachable.

### Step 7 - Notify user

If tests pass AND `verification.md` **Result** is not FAIL: `bash "$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh" set plan tested` (refuses a missing or FAIL `verification.md`).

Evidence = the stamp result lines (counts + log path), copied as printed — never "all tests passed" from memory.

```text
✅ Tests complete: [type]/[NNN]_[feature-name]

Unit:          [stamp line — e.g. ✓ test: pass (41s) · 120 passed · 0 failed · 2 skipped · log: .devflow-verify/test.log]
Integration:   [one stamp line per e2e target, or "no target defined"]
Verification:  [PASS | FAIL | PARTIAL] — [N]/[N] ACs · devflow/features/[NNN]_[feature-name]/verification.md
[FAIL verdicts with level + evidence]

[Failures — only after 3 attempts]
- [test file] :: [test name] — [decisive error line from the log] — 3/3 attempts: [what was tried]

---

Next: /devflow-ship — multi-agent review gate before the PR (it reuses these stamps; devflow.pr runs the full suite and the build).
```

No menu: ship is the only next step (skipping it skips the review gate; the full suite already runs in `devflow.pr` Step 3). **Run mode** (`.devflow-run.json` present): control returns to the orchestrator (`devflow.run` stops at its `--until` boundary, or `devflow.auto` continues to `devflow.ship`).

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
| Pasting test output into the report | Stamp lines carry counts + log path; the log is the evidence (`token-economy.md`) |
| Skipping `testing-patterns.md` for novel scenarios | Read `$HOME/.gemini/antigravity-cli/plugins/devflow/references/testing-patterns.md` first |
| Skipping verification because tests pass | Tests are forward-looking; Step 6b proves each AC exists, is real, is wired |
| Setting `tested` with FAIL verdicts in verification.md | FAIL = not tested; fix or route to `devflow.backprop` |

## I/O Reference

| | |
| --- | --- |
| Reads | files from `devflow.implement` / `devflow.beautify` summary |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md`, `registry.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md`, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/ADAPTER.md` (core) + `steps/test.md` |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/references/verification-levels.md` (Step 6b), `$HOME/.gemini/antigravity-cli/plugins/devflow/references/escalation-ladder.md` (failure handling), `$HOME/.gemini/antigravity-cli/plugins/devflow/references/state-machine.md` (handoff format, context pressure only), `$HOME/.gemini/antigravity-cli/plugins/devflow/references/complexity-scoring.md` (depth profile), `$HOME/.gemini/antigravity-cli/plugins/devflow/references/token-economy.md` (output discipline) |
| Reads (conditional) | `.devflow-run.json` (existence — run-mode switch) |
| Reads (optional) | `$HOME/.gemini/antigravity-cli/plugins/devflow/references/testing-patterns.md` — stack-agnostic patterns reference |
| Reads (optional) | `.devflow-test-summary.json` — structured pass/fail/skipped counts from the most recent recognized test-runner command (written by `post-bash-output-filter.sh`; cross-check only, not evidence of record) |
| Writes | Test output paths per the adapter test step file |
| Writes | `devflow/features/[NNN]_[feature-name]/verification.md` — per-AC verdict table |
| Writes | `devflow/features/[NNN]_[feature-name]/.checkpoint.json` — `errors_tried` on retry loops, via `$HOME/.gemini/antigravity-cli/plugins/devflow/scripts/devflow-state.sh` |
| Writes (conditional) | `devflow/features/[NNN]_[feature-name]/handoff.md` — on context pressure (state-machine.md → Handoff file) |
| Writes | `plan.md` — `**Status:** tested` (only when tests pass + verification has no FAIL) |
| Next step | `devflow.ship` (or `devflow.pr` directly for solo quick changes) |
