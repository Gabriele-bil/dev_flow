# NestJS adapter — Test step

Loaded by `devflow-test` (and `devflow-backprop` for test conventions) together with the adapter core (`ADAPTER.md`).

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated `*.spec.ts` next to the source file (`users.service.spec.ts` next to `users.service.ts`).
- E2E: `test/*.e2e-spec.ts`, one file per feature/controller (`test/users.e2e-spec.ts`), Supertest against the bootstrapped app.

### Commands

Runner per `ADAPTER.md` → Project choices (Vitest in ESM projects, Jest 30 in CommonJS). Both accept these flags:

```bash
npm test -- --passWithNoTests --coverage
npm run test:e2e
```

### Required test focus

- Services: business logic branches, error paths, DI substitution via `Test.createTestingModule`.
- Controllers/DTOs: invalid input → `400` (both validation pipes), guards reject unauthorized (`401`/`403`).
- Data access: query correctness, transaction rollback on failure.
- External services (payment, email, third-party APIs): mocked — never called for real in unit or e2e tests.

### Verify (runtime)

Level-4 goal-backward verification target (`devflow.test` Step 6b). Run e2e specs covering the AC under verification — Supertest boots the real Nest application (all modules, guards, pipes, filters wired) and exercises it over HTTP in-process:

```bash
npm run test:e2e -- --testPathPatterns "[feature-name]"   # Jest 30
npm run test:e2e -- "[feature-name]"                      # Vitest (substring filter, no regex)
```

No e2e spec covering the AC → level 4 `N/A` (verdict PARTIAL).
