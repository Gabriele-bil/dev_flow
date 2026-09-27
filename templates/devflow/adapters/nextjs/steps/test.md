# Next.js adapter — Test step

Loaded by `devflow-test` (and `devflow-backprop` for test conventions) together with the adapter core (`ADAPTER.md`).

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated `*.test.tsx` / `*.test.ts` in same directory as source file.
- Integration: `__tests__/` at feature level or project root.

### Commands

```bash
pnpm test -- --passWithNoTests --watchAll=false --coverage
```

### Required test focus

- Components: conditional rendering, prop contract, accessibility-critical states.
- Forms: validator behavior, submit disable/enable transitions, error display.
- State (Zustand): state transitions, selector output.
- Server Actions / API Routes: success/error mapping.

### Verify (runtime)

Level-4 goal-backward verification targets (`devflow.test` Step 6b):

- **Level 4a (API / Server Actions):** Run route/integration tests covering server logic.
- **Level 4b (UI / Browser Workflow):** Run Playwright smoke spec covering the AC under verification:

```bash
pnpm exec playwright test --grep "[feature-name]"
```

When running in an agentic environment with browser tools (e.g. `browser_subagent`):
1. Start or verify dev server is running (`pnpm dev`).
2. Navigate to the feature route in headless/interactive browser.
3. Assert page mounts cleanly: no unhandled exceptions, zero fatal console errors.
4. Execute the critical user interaction flow (fill form, trigger action, observe DOM state transition).
5. Record confirmation evidence in `verification.md`.

No Playwright setup, no spec covering the AC, and no browser tool available → level 4 `N/A` (verdict PARTIAL).
