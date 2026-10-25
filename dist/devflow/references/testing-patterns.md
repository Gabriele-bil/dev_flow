# Testing Patterns

Stack-agnostic. Use alongside `devflow-test` and adapter technology test skills.
Framework-specific patterns in active `ADAPTER.md` → **Technology skills → testing**.

## Test Structure: Arrange-Act-Assert (AAA)

```text
// Arrange: set up data and preconditions
// Act: perform action under test
// Assert: verify outcome
```

Every test follows AAA. Name describes behavior under test, not implementation.

## Test Naming

Pattern: `[unit] [expected behavior] [condition]`

```text
describe('TaskService.createTask')
  it('returns task with pending status')
  it('throws ValidationError when title empty')
  it('trims whitespace from title')
```

## Mock Boundaries

Mock only at system boundaries. Never mock internals.

```text
Mock:                          Do not mock:
├── Database calls             ├── Internal utility functions
├── HTTP / network requests    ├── Business logic
├── File system                ├── Data transformations
├── External APIs              ├── Validation functions
└── Time/Date (non-determinism)└── Pure functions
```

## Test Types and Pyramid

| Type | Coverage target | What it tests |
| ------ | ---------------- | --------------- |
| Unit (80%) | Domain logic, models, state methods | Inputs → outputs, error paths |
| Integration (15%) | User flows end-to-end, service boundaries | Wired behavior across layers |
| E2E (5%) | Critical user journeys only | Full stack from UI to data |

Inverted pyramids (many E2E, few unit) are fragile and slow. Build the pyramid correctly.

## Beyonce Rule

If behavior matters enough to keep, put a test on it. No "too simple to test" exceptions.

## Prove-It Pattern (Bug Fixes)

1. Write test that **reproduces** the bug — must fail before fix
2. Implement fix
3. Confirm test now passes
4. Test is permanent proof the bug is fixed

## Coverage Gap Inventory

Before writing tests:

1. List all public functions/classes/state methods in scope
2. For each: happy path + at least one error/edge case
3. Explicitly flag surfaces with no coverage — never skip silently

## Test Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Testing implementation details | Breaks on refactor | Test inputs/outputs, not internals |
| Snapshot everything | Diffs never reviewed | Assert specific values |
| Shared mutable state between tests | Tests pollute each other | Setup/teardown per test |
| Testing third-party code | Not your bug | Mock the boundary |
| `skip` permanently | Dead code | Remove or fix |
| No async error handling | Swallowed errors, false passes | Always `await` async tests |
| Overly broad assertions | Misses regressions | Be specific |
| Manual testing only | Not verifiable, not repeatable | Automate every flow that matters |

## Pass@k vs Pass^k

| Metric | Meaning | Use for |
| --- | --- | --- |
| **pass@k** | At least 1 of k attempts passes | Proving capability exists; LLM eval |
| **pass^k** | All k attempts pass | Proving reliability; production gate |

In `devflow-test`: target **pass^k ≥ 1** for all written tests. A test that passes only sometimes is a flaky test — fix or remove.

## Paired Control Protocol (Flake vs Regression Isolation)

Before blaming current feature changes for an unexpected failure or dismissing a red test as a flake:

1. **Isolation run:** run the failing test file alone. If it passes alone but fails in the suite → shared state or ordering pollution between tests; fix test setup/teardown.
2. **Paired control (candidate vs baseline):** if an untouched test fails in isolation, run the exact same command on the pre-feature baseline (`devflow-checkpoint/<branch>/implement` or `main`) and on the candidate branch:
   - Control **passes** + candidate **fails** → genuine regression caused by this feature; fix before proceeding.
   - Control **fails** + candidate **fails** → pre-existing broken test on baseline; document both command outputs as evidence in the test report and log via `devflow.learn`. Never silently skip without paired evidence.

## Canonical Edge Matrix

Most bugs live at an edge the happy-path test skipped. When writing edge tests (`standard` / `thorough`), probe:

- **Numbers:** `0`, `1`, exact max limit, `limit + 1`, negative values
- **Dates/Times:** `today`, `yesterday`, timezone offset / midnight boundary
- **Lists:** empty `[]`, single item, first and last item, duplicates
- **Containment:** tests that write files or state must use temporary directories/sandboxes and never mutate global home or tracked repo files

## Verification Checkpoints (Multi-Step Features)

Set explicit checkpoints during `devflow-implement`:

1. Define acceptance criteria per subtask in `plan.md`
2. Run subset of tests at each checkpoint — don't wait for full suite
3. Fix failures before proceeding to next subtask
4. Full suite only at `devflow-test` step

```text
subtask complete → checkpoint test → pass? → next subtask
                                    fail? → fix here, not later
```

## Coverage: What Counts

Coverage % alone is misleading. These matter more:

| Signal | Interpretation |
| -------- | --------------- |
| Branch coverage < 70% | Missing error path tests |
| All happy paths, no error paths | False confidence |
| Tests pass but coverage 0% | Test imports wrong module |
| High coverage, no assertions | Tests exist but prove nothing |

Run coverage with assertions: `if coverage > 0 but 0 assertions → fail`.
