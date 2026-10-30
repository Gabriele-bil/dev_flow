# Angular Testing — project decisions

Loaded on demand from `../SKILL.md`. Vitest and TestBed APIs: check current docs with Context7 (`/websites/angular_dev` "testing", `/vitest-dev/vitest`) before using an unfamiliar matcher or builder option.

## Outputs

Subscribe to the `output()` ref, trigger the DOM event, wait, assert:

```typescript
let emitted: Item | undefined;
fixture.componentInstance.selected.subscribe((v) => (emitted = v));
fixture.nativeElement.querySelector("button").click();
await fixture.whenStable();
expect(emitted).toEqual(item);
```

## Debounce / timers

```typescript
beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

it("debounces search", async () => {
  fixture.componentInstance.query.set("ng");
  await vi.advanceTimersByTimeAsync(300);
  await fixture.whenStable();
  expect(store.value().length).toBeGreaterThan(0);
});
```

## Router and guards

Drive the real router — guards and resolvers run:

```typescript
TestBed.configureTestingModule({
  providers: [
    provideRouter([{ path: "admin", component: AdminPage, canActivate: [authGuard] }, { path: "login", component: LoginPage }]),
    { provide: AuthStore, useValue: { isAuthenticated: () => false } },
  ],
});
const harness = await RouterTestingHarness.create();
await harness.navigateByUrl("/admin");
expect(TestBed.inject(Router).url).toBe("/login");
```

## Harnesses

Reusable widgets get a `ComponentHarness` (`@angular/cdk/testing`) next to the component; specs load it with `TestbedHarnessEnvironment.loader(fixture)` and filter with `Harness.with({ … })`. Assert with Vitest matchers (`toBe(false)`) — Jasmine matchers like `toBeFalse()` are not supported.

## Stores

Provide the store + mocked services, call methods, assert signals. Seed protected state with `patchState(unprotected(store), …)`.

## E2E (Playwright)

- Specs in `e2e/`, run by the project `e2e` script.
- Locators: `getByRole` / `getByLabel` first, `getByTestId` (`data-testid`) when no accessible name. No CSS-class or text-copy selectors.
- No fixed sleeps (`waitForTimeout`) — rely on auto-waiting `expect(locator).toBeVisible()`.
- Repeated flows (login, seed) → fixtures or `storageState`, not copy-paste.
