# Angular adapter — Test step

Loaded by `devflow-test` (and `devflow-backprop` for test conventions) together with the adapter core (`ADAPTER.md`).

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated `*.spec.ts` or mirrored under `src/` by project convention.
- Integration: feature-level TestBed specs (page + store + mocked HTTP), conventions in `angular-testing`.
- E2E: Playwright specs in `e2e/` (`@playwright/test`, installed by setup).

### Commands

Use project scripts first:

```bash
pnpm run test -- --watch=false
```

If e2e exists:

```bash
pnpm run e2e
```

### Required test focus

- Components: input/output contract, conditional rendering, accessibility-critical states.
- Forms: validator behavior, submit disable/enable transitions, error display.
- State: state/store contracts and transitions for each changed path.
- HTTP: success/error/timeout mapping through data layer.

### Verify (runtime)

Level-4 goal-backward verification targets (`devflow.test` Step 6b):

- **Level 4a (Services / HTTP):** Run integration tests covering HTTP and state layer.
- **Level 4b (UI / Browser Workflow):** When project defines Playwright e2e, run specs covering the AC:

```bash
pnpm run e2e -- --grep "[feature-name]"
```

When running in an agentic environment with browser tools (e.g. `browser_subagent`):

1. Start or verify dev server is running (`pnpm start` / `ng serve`).
2. Navigate to feature route; verify component mounts without runtime console errors.
3. Perform user flow (reactive form submission, route transition, state change).
4. Verify expected DOM elements appear with correct accessibility semantics.
5. Record confirmation evidence in `verification.md`.

No e2e setup, no spec covering the AC, and no browser tool available → level 4 `N/A` (verdict PARTIAL).
