---
name: devflow-test
description: Writes and executes unit and integration tests for the current DevFlow feature across Android emulator and Chrome, with bounded retry handling and standardized reporting. Use when the user asks to run devflow.test, validate a DevFlow feature after beautify, or execute the fifth step of the DevFlow pipeline.
argument-hint: [optional-plan-path]
disable-model-invocation: true
---

# Skill: devflow.test

## Quick Start

Run `/devflow.test [optional plan path]`.

- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, resolve the latest `devflow/features/*/plan.md`

## Purpose

Write/run tests for current feature per active adapter **Test** section (for example Flutter: unit + integration on Android/Chrome). Fifth DevFlow step.

## When NOT to Use

- The adapter’s analyze/typecheck command still reports errors — tests cannot be meaningful until the code compiles cleanly
- Neither `devflow.implement` nor `devflow.beautify` has run for this feature — there is no code to test
- The goal is to test a pre-existing feature not modified in this DevFlow run — open a separate task for that

## Input

- List of files created/modified by `devflow.implement` and `devflow.beautify`
- `devflow/features/[NNN]_[feature-name]/plan.md`
- If an argument is passed, use it as the `plan.md` path
- If no argument is passed, resolve the latest `devflow/features/*/plan.md`

## Workflow

### Step 0 - Resolve adapter

Read `@devflow/config.md` and `@devflow/adapters/<adapter>/ADAPTER.md`. The **Test** section defines placement, frameworks, coverage expectations, and shell commands — follow it exactly for this run.

### Step 1 - Read docs

Always read before starting:

- `constitution.md`
- `registry.md`

### Step 2 - Scope

Test only files belonging to the current feature.

- Do not write tests for shared/core files or pre-existing code unless they were modified in this DevFlow run
- Keep test additions focused on files touched by current feature implementation

### Step 3 through 6 - Author and run tests

Using `task.md`, `plan.md`, and the implement/beautify summaries:

1. **Placement** — mirror source layout and integration paths per `ADAPTER.md` → **Test**.
2. **Unit tests** — cover models, state, domain rules, and UI assertions per `ADAPTER.md` (load any technology skills it references).
3. **Integration tests** — target user flows from `task.md` per `ADAPTER.md` (targets, devices, order).
4. **Execute** — run the exact commands from `ADAPTER.md`; paste raw stdout/stderr in the Step 7 report.

Failure handling:

- Max 3 attempts per failing test
- Attempt 1: analyze failure output and fix the test or implementation
- Attempt 2: verify mocks and dependencies are correctly set up
- Attempt 3: isolate and fix root cause
- If still failing after 3 attempts: stop retries and report using failure format

### Step 7 - Notify user

After execution, include actual command output. Do NOT report "all tests passed" without raw evidence.

```text
✅ Tests complete: [type]/[NNN]-[feature-name]

### Unit tests
[N] passed · [N] failed · [N] skipped

Output:
```
[paste actual unit test command output here]
```

### Integration - Android
[N] passed · [N] failed

Output:
```
[paste actual integration test output here]
```

### Integration - Chrome
[N] passed · [N] failed

Output:
```
[paste actual integration test output here]
```

[-- Failures --]
(shown only if any test failed after 3 attempts)

#### [test file path]
- Test: [test name]
- Error: [error message]
- Attempts: 3/3 - unresolved
- Notes: [what was tried]

---

All tests passing? Choose how to continue:
1. Run full project test suite before opening PR -> devflow.pr
2. Skip full suite and open PR directly -> devflow.pr
```

Wait for user choice before continuing.

## Common Rationalizations

| Thought | Reality |
|---------|---------|
| "I'll write tests after the PR is open" | Tests are a pre-condition for `devflow.pr`; the PR checklist cannot be completed without passing tests |
| "I tested manually — that's enough" | Manual testing is not verifiable; automated tests are required for the PR checklist |
| "This file is too simple to need tests" | Simple files break too; a trivial test is better than no test; if truly untestable, document why in the Step 7 report |
| "I'll skip integration tests to save time" | Integration tests cover user flows that unit tests cannot; run every integration target required by `ADAPTER.md` |
| "3 retries failed — I'll just mark it as passing" | After 3 failures, stop and report; never mark a failing test as passing in the summary |

## I/O Reference

| | |
|---|---|
| Reads | files from `devflow.implement` / `devflow.beautify` summary |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md`, `registry.md`, `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Writes | Test output paths per active `ADAPTER.md` → **Test** |
| Next step | `devflow.pr` |
