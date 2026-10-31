---
name: angular-testing
description: Angular v22+ unit + integration tests with Vitest. Use for component (signals, OnPush), service, HTTP, or routing tests. Triggers on test creation, mocking, or coverage tasks. Skip for E2E (Playwright) or non-Angular code.
---

# Angular Testing

## Purpose

Write zoneless Vitest + TestBed specs for Angular v22 components, services, stores, HTTP and routing.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no `*.spec.ts` touched).
- E2E specs (Playwright, `e2e/`) → `steps/test.md` conventions; only the E2E notes in the reference apply.
- Non-Angular utility code with no TestBed — plain Vitest, no skill needed.

## Baseline

- Runner: Vitest via `@angular/build:unit-test` (`ng test`) — default since v21. Karma/Jasmine: not supported for new specs.
- Zoneless is the default. Pattern **Act → Wait → Assert**: change input/signal or dispatch event → `await fixture.whenStable()` → assert DOM/state.
- `fixture.detectChanges()` only in legacy specs; new specs wait with `whenStable()`.
- Signal inputs: `fixture.componentRef.setInput('name', value)`.
- Timers: `vi.useFakeTimers()` + `await vi.advanceTimersByTimeAsync(ms)`. Do not use `fakeAsync`/`waitForAsync` — they need zone.js.
- Mocks: `vi.fn()` objects via `{ provide: X, useValue: mock }`. Real `provideRouter([...])` + `RouterTestingHarness`, never a mocked `Router`.
- HTTP: `provideHttpClientTesting()` + `HttpTestingController` (`angular-http` reference).

```typescript
it("shows new title", async () => {
  const fixture = TestBed.createComponent(TitleCard);
  fixture.componentRef.setInput("title", "New title");
  await fixture.whenStable();
  expect(fixture.nativeElement.textContent).toContain("New title");
});
```

```bash
pnpm run test -- --watch=false
pnpm run test -- --watch=false --coverage
```

## Quality Rules

- Assert behavior (rendered text, emitted outputs, store signals), not private members.
- Deterministic: no real network, time or randomness.
- One behavior per test; shared setup in helpers.
- Prefer CDK component harnesses over `querySelector` for reusable widgets.

Harnesses, router guard tests, store tests, E2E conventions: [references/testing-patterns.md](references/testing-patterns.md).

## I/O Reference

|            |                                                                |
| ---------- | -------------------------------------------------------------- |
| Reads      | Active spec/test files, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Vitest + TestBed spec files                  |
| Invoked by | `devflow.implement`, `devflow.test`                            |
