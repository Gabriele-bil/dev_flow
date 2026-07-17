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

Level-4 goal-backward verification target (`devflow.test` Step 6b) — only when Playwright is configured. Run smoke specs covering the AC under verification:

```bash
pnpm exec playwright test --grep "[feature-name]"
```

No Playwright setup or no spec covering the AC → level 4 `N/A` (verdict PARTIAL).
