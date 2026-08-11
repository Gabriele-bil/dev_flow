---
name: nestjs-testing
description: TestingModule unit tests, Supertest e2e tests, mocking external services/repositories. Load when creating or refactoring *.spec.ts, *.e2e-spec.ts, or test fixtures/mocks.
---

# Skill: NestJS Testing

Use when writing unit tests (`*.spec.ts`), e2e tests (`*.e2e-spec.ts`), or mocking repositories/HTTP clients/SDKs.

Full code examples: `references/testing-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (not a test file)
- Test-runner/CI config changes with no test-code change — see `steps/test.md`

## Objectives

- Every service/guard/interceptor unit-tested via `Test.createTestingModule` with mocked providers — never manual `new Service(realDep)`.
- Every controller has at least one `*.e2e-spec.ts` exercising the real HTTP stack (guards, pipes, interceptors, serialization) via Supertest.
- No real external service, database, or SDK called in a unit test — always mocked.
- Tests assert observable behavior/outcomes, not internal call sequences.

## 1) Use TestingModule for Unit Tests (HIGH)

`Test.createTestingModule({ providers: [ServiceUnderTest, { provide: Dependency, useValue: mockObject }] }).compile()` — never `new UsersService(new UserRepository())` (bypasses DI, may hit a real DB). Mock every constructor dependency explicitly with `jest.fn()` per method used. `module.get<T>(Token)` retrieves both the unit under test and its mocks for assertion. Guards/interceptors get the same treatment — instantiate via `TestingModule`, not `new RolesGuard()`, so `Reflector` and other DI'd collaborators are real or properly mocked.

## 2) Use Supertest for E2E Testing (HIGH)

`*.e2e-spec.ts` boots the real app: `Test.createTestingModule({ imports: [AppModule] }).compile()` then `moduleFixture.createNestApplication()` then `app.init()`. Apply the exact same global config as production (`app.useGlobalPipes(new ValidationPipe(...))`) — an e2e test with different pipe config than `main.ts` doesn't actually validate the real request path. Drive requests with `request(app.getHttpServer()).post('/users').send(...).expect(201)`. Always `app.close()` in `afterAll`; for DB-backed e2e suites, isolate/reset state in `beforeEach` (test DB, transaction rollback, or `synchronize(true)` against a dedicated test datasource — never the dev/prod DB).

## 3) Mock External Services (HIGH)

Never call a real Stripe/HTTP/queue client or real database in a unit test — slow, costs money, flaky, non-deterministic. Mock at the injection boundary: `{ provide: HttpService, useValue: { get: jest.fn(), post: jest.fn() } }`, `{ provide: getRepositoryToken(User), useValue: mockRepo }`. Cover error paths explicitly (`httpService.get.mockReturnValue(throwError(() => new Error('ETIMEDOUT')))`), not just the happy path. For complex third-party SDKs, write one shared mock factory (`createMockStripe()`) reused across test files instead of ad hoc partial mocks that silently miss methods. Mock time (`jest.useFakeTimers()` / `jest.setSystemTime()`) for expiry/scheduling logic instead of real `setTimeout` waits.

## Testing Checklist

- [ ] Unit tests use `Test.createTestingModule`, not manual `new Service(...)`
- [ ] Every constructor dependency mocked with explicit `jest.fn()` per used method
- [ ] Controllers have a matching `*.e2e-spec.ts` using Supertest against a booted app
- [ ] E2E test applies the same global pipes/filters/interceptors as `main.ts`
- [ ] No real external service/DB/SDK call in a unit test
- [ ] Error/edge-case paths (timeout, 4xx, empty result) covered, not just happy path
- [ ] `app.close()` / mock cleanup (`jest.clearAllMocks()`) in `afterEach`/`afterAll`

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-test` and `devflow-implement` when file path matches `*.spec.ts` or `*.e2e-spec.ts` |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md`, `steps/test.md` |
| Related | `nestjs-architecture` (DI shape under test), `nestjs-security` (guard test patterns) |
