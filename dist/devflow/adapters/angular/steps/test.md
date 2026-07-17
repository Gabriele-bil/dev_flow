# Angular adapter — Test step

Loaded by `devflow-test` (and `devflow-backprop` for test conventions) together with the adapter core (`ADAPTER.md`).

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated `*.spec.ts` or mirrored under `src/` by project convention.
- Integration: feature-level flows in project’s selected framework (Angular TestBed / Cypress / Playwright).

### Commands

Use project scripts first:

```bash
npm run test -- --watch=false
```

If e2e exists:

```bash
npm run e2e
```

### Required test focus

- Components: input/output contract, conditional rendering, accessibility-critical states.
- Forms: validator behavior, submit disable/enable transitions, error display.
- State: state/store contracts and transitions for each changed path.
- HTTP: success/error/timeout mapping through data layer.

### Verify (runtime)

Level-4 goal-backward verification target (`devflow.test` Step 6b) — only when project defines e2e (Cypress/Playwright). Run specs covering the AC under verification:

```bash
npm run e2e -- --grep "[feature-name]"
```

No e2e setup or no spec covering the AC → level 4 `N/A` (verdict PARTIAL).
