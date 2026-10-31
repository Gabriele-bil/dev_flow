---
name: nestjs-testing
description: TestingModule unit tests, Supertest e2e tests, mocking repositories and external services, on Vitest (ESM) or Jest 30 (CommonJS). Load when creating or refactoring *.spec.ts, *.e2e-spec.ts, or test fixtures/mocks.
---

# Skill: NestJS Testing

## Purpose

Project rules for unit and e2e tests of NestJS code. Layout, commands and coverage threshold: `steps/test.md`. Examples: `references/testing-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-testing`
- Runner/CI configuration without test code — see `steps/test.md`
- Deciding what a feature must cover — `devflow-test` owns that

## Rules

1. **Runner per project** (`ADAPTER.md` → Project choices): Vitest → `vi.fn()`, `vi.spyOn`, `vi.useFakeTimers()`; Jest → `jest.*`. Never mix in one repo. `@nestjs/testing` is runner-agnostic. Vitest needs SWC (`unplugin-swc`) for decorator metadata — do not remove it from `vitest.config.ts`.
2. **Unit = `Test.createTestingModule`** with every constructor dependency replaced via `{ provide: Token, useValue: mock }`; fetch unit and mocks with `module.get()`. Never `new Service(realDep)`. Guards/interceptors the same way, so `Reflector` is real.
3. **Mock at the injection boundary.** Repository token (`getRepositoryToken(User)`) or `PrismaService`; `HttpService` returning `of(...)` / `throwError(...)`; one shared factory per complex SDK (`createMockStripe()`). No real DB, network, queue or SDK in unit tests.
4. **E2E boots the real app.** `Test.createTestingModule({ imports: [AppModule] })` → `createNestApplication()` → same bootstrap as `main.ts` (pipes, filters, security headers, versioning — extract a `configureApp(app)` and call it in both) → `app.init()`; `request(app.getHttpServer())`; `app.close()` in `afterAll`.
5. **Isolated data.** E2E DB is a dedicated test database or container, reset per suite (migrations + truncate) — never dev/prod. Override external clients with `.overrideProvider(X).useValue(...)`.
6. **Behavior over calls.** Assert results, status codes, thrown exception types, persisted state. `toHaveBeenCalledWith` only where the call itself is the contract (e.g. email sent).
7. **Error paths are required:** not found, conflict, invalid input (`400`), unauthenticated (`401`), forbidden (`403`), upstream timeout. Time-dependent logic uses fake timers, never real waits.
8. **Dynamic modules in tests.** Since Nest 11 dynamic modules are not deduplicated by config — import the shared constant (`nestjs-architecture` rule 3) or tests may get two instances.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-test` per `steps/implement.md` → skill load decision matrix |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nestjs/ADAPTER.md`, `steps/test.md`, `references/testing-patterns.md` |
| Related | `nestjs-architecture` (DI shape under test), `nestjs-database` (repository mocks per ORM), `nestjs-security` (guard tests) |
