# Testing Patterns

Stack-agnostic. Use alongside `devflow-test` and adapter technology test skills.
Framework-specific patterns in active `ADAPTER.md` → **Technology skills → testing**.

## Test Structure: Arrange-Act-Assert (AAA)

```
// Arrange: set up data and preconditions
// Act: perform action under test
// Assert: verify outcome
```

Every test follows AAA. Name describes behavior under test, not implementation.

## Test Naming

Pattern: `[unit] [expected behavior] [condition]`

```
describe('TaskService.createTask')
  it('returns task with pending status')
  it('throws ValidationError when title empty')
  it('trims whitespace from title')
```

## Mock Boundaries

Mock only at system boundaries. Never mock internals.

```
Mock:                          Do not mock:
├── Database calls             ├── Internal utility functions
├── HTTP / network requests    ├── Business logic
├── File system                ├── Data transformations
├── External APIs              ├── Validation functions
└── Time/Date (non-determinism)└── Pure functions
```

## Test Types and Pyramid

| Type | Coverage target | What it tests |
|------|----------------|---------------|
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
|---|---|---|
| Testing implementation details | Breaks on refactor | Test inputs/outputs, not internals |
| Snapshot everything | Diffs never reviewed | Assert specific values |
| Shared mutable state between tests | Tests pollute each other | Setup/teardown per test |
| Testing third-party code | Not your bug | Mock the boundary |
| `skip` permanently | Dead code | Remove or fix |
| No async error handling | Swallowed errors, false passes | Always `await` async tests |
| Overly broad assertions | Misses regressions | Be specific |
| Manual testing only | Not verifiable, not repeatable | Automate every flow that matters |
