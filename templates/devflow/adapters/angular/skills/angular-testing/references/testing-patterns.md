# Angular Testing Patterns

## Table of Contents
- [Vitest Advanced Patterns](#vitest-advanced-patterns)
- [Component Harnesses](#component-harnesses)
- [Testing Router](#testing-router)
- [E2E Testing (Cypress)](#e2e-testing-cypress)
- [Testing Forms](#testing-forms)
- [Testing Directives](#testing-directives)
- [Testing Pipes](#testing-pipes)
- [Test Utilities](#test-utilities)

## Vitest Advanced Patterns

### Snapshot Testing

```typescript
import { describe, it, expect } from 'vitest';

describe('UserCardComponent', () => {
  it('matches snapshot', async () => {
    const fixture = TestBed.createComponent(UserCardComponent);
    fixture.componentRef.setInput('user', {
      id: '1',
      name: 'John',
      email: 'john@example.com',
    });
    await fixture.whenStable();

    expect(fixture.nativeElement.innerHTML).toMatchSnapshot();
  });
});
```

### Parameterized Tests

```typescript
import { describe, expect, it } from 'vitest';

describe('email validator', () => {
  it.each([
    { input: '', expected: false },
    { input: 'test', expected: false },
    { input: 'test@example.com', expected: true },
    { input: 'invalid@', expected: false },
  ])('validates "$input" as $expected', ({ input, expected }) => {
    expect(isValidEmail(input)).toBe(expected);
  });
});
```

### Fake Timers

```typescript
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

describe('DebouncedSearchComponent', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('debounces user query', async () => {
    const fixture = TestBed.createComponent(DebouncedSearchComponent);
    fixture.componentInstance.query.set('test');

    vi.advanceTimersByTime(300);
    await fixture.whenStable();

    expect(fixture.componentInstance.results().length).toBeGreaterThan(0);
  });
});
```

### Module Mocking

```typescript
import { describe, expect, it, vi } from 'vitest';

vi.mock('./analytics.service', () => ({
  AnalyticsService: class {
    track = vi.fn();
    identify = vi.fn();
  },
}));

describe('DashboardComponent', () => {
  it('tracks dashboard view', async () => {
    const fixture = TestBed.createComponent(DashboardComponent);
    const analytics = TestBed.inject(AnalyticsService);

    await fixture.whenStable();
    expect(analytics.track).toHaveBeenCalledWith('dashboard_viewed');
  });
});
```

## Component Harnesses

Use CDK harness for stable selectors and reusable interactions.

```typescript
import { ComponentHarness } from '@angular/cdk/testing';

export class CounterHarness extends ComponentHarness {
  static hostSelector = 'app-counter';

  private getIncrementButton = this.locatorFor('button.increment');
  private getCountLabel = this.locatorFor('.count');

  async increment(): Promise<void> {
    const button = await this.getIncrementButton();
    await button.click();
  }

  async getCount(): Promise<number> {
    const label = await this.getCountLabel();
    return Number(await label.text());
  }
}
```

```typescript
import { TestbedHarnessEnvironment } from '@angular/cdk/testing/testbed';

it('increments using harness', async () => {
  const fixture = TestBed.createComponent(CounterComponent);
  const loader = TestbedHarnessEnvironment.loader(fixture);
  const counter = await loader.getHarness(CounterHarness);

  expect(await counter.getCount()).toBe(0);
  await counter.increment();
  expect(await counter.getCount()).toBe(1);
});
```

### Locating with `.with()` Predicates

Use `HarnessPredicate` (via static `.with()`) to find a specific instance among many — assert on user-visible attributes, not DOM structure:

```typescript
const cardHarness = await loader.getHarness(
  UserCardHarness.with({ name: "Jane Doe" }),
);

const allCards = await loader.getAllHarnesses(UserCardHarness);
const disabledButton = await loader.getHarness(
  ButtonHarness.with({ disabled: true }),
);
```

Prefer behavior-level assertions (`await harness.isExpanded()`, `await harness.getText()`) over `fixture.nativeElement.querySelector(...)` — harnesses survive template refactors, raw selectors don't.

## Testing Router

Use `provideRouter` + `RouterTestingHarness`.

```typescript
import { provideRouter } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';

it('navigates to user page', async () => {
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: '', component: HomeComponent },
        { path: 'users/:id', component: UserComponent },
      ]),
    ],
  });

  const harness = await RouterTestingHarness.create();
  const component = await harness.navigateByUrl('/users/123', UserComponent);
  expect(component.id()).toBe('123');
});
```

Provide real routes via `provideRouter([...])` — do NOT mock `Router`. `RouterTestingHarness` drives actual navigation through guards/resolvers, exercising the real pipeline. Combine with the zoneless `await harness.fixture.whenStable()` pattern for post-navigation assertions:

```typescript
it('blocks navigation when unauthenticated', async () => {
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: 'admin', component: AdminPage, canActivate: [authGuard] },
        { path: 'login', component: LoginPage },
      ]),
      { provide: AuthStore, useValue: { isAuthenticated: () => false } },
    ],
  });

  const harness = await RouterTestingHarness.create();
  await harness.navigateByUrl('/admin');
  await harness.fixture.whenStable();

  expect(harness.routeNativeElement?.querySelector('app-login')).toBeTruthy();
});
```

## E2E Testing (Cypress)

Out of scope for `angular-testing` unit work, but conventions to follow when authoring Cypress specs in the same repo:

- **`data-cy` attribute convention** — target elements via `data-cy="submit-button"`, never CSS classes or text content (both churn with styling/copy changes).

```html
<button data-cy="submit-button" [disabled]="form().invalid()">Submit</button>
```

```typescript
cy.get('[data-cy="submit-button"]').click();
```

- **Custom commands in `support/`** — wrap repeated flows (login, seed-data) as `Cypress.Commands.add(...)` in `cypress/support/commands.ts`, not copy-pasted across specs.

```typescript
Cypress.Commands.add("loginAs", (role: "admin" | "member") => {
  cy.session(role, () => {
    cy.visit("/login");
    cy.get('[data-cy="email"]').type(`${role}@example.com`);
    cy.get('[data-cy="password"]').type("test-password");
    cy.get('[data-cy="submit-button"]').click();
    cy.url().should("not.include", "/login");
  });
});
```

- **Prefer element-wait over `cy.wait(ms)`** — fixed delays are flaky and slow. Wait on the element/state that signals readiness:

```typescript
// WRONG — arbitrary fixed delay
cy.wait(2000);
cy.get('[data-cy="results"]').should("be.visible");

// RIGHT — wait for the actual signal of readiness
cy.get('[data-cy="results"]').should("be.visible");
cy.get('[data-cy="loading-spinner"]').should("not.exist");
```

## Testing Forms

Focus Signal Forms behavior and state.

```typescript
it('validates signal form', async () => {
  const fixture = TestBed.createComponent(LoginFormComponent);
  const component = fixture.componentInstance;

  component.model.set({ email: 'test@example.com', password: 'password123' });
  await fixture.whenStable();

  expect(component.loginForm().valid()).toBe(true);
});
```

## Testing Directives

```typescript
it('applies highlight color', async () => {
  @Component({
    imports: [HighlightDirective],
    template: `<p appHighlight="lightblue">Test</p>`,
  })
  class HostComponent {}

  const fixture = TestBed.createComponent(HostComponent);
  await fixture.whenStable();

  const p = fixture.nativeElement.querySelector('p');
  expect(p.style.backgroundColor).toBe('lightblue');
});
```

## Testing Pipes

```typescript
describe('TruncatePipe', () => {
  let pipe: TruncatePipe;

  beforeEach(() => {
    pipe = new TruncatePipe();
  });

  it('truncates long strings', () => {
    expect(pipe.transform('Hello World', 5)).toBe('Hello...');
  });
});
```

## Test Utilities

```typescript
import { ComponentFixture } from '@angular/core/testing';

export function setSignalInput<T>(
  fixture: ComponentFixture<unknown>,
  inputName: string,
  value: T
): Promise<void> {
  fixture.componentRef.setInput(inputName, value);
  return fixture.whenStable();
}

export async function waitForSignal<T>(
  read: () => T,
  predicate: (value: T) => boolean,
  timeoutMs = 5000
): Promise<T> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const value = read();
    if (predicate(value)) return value;
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  throw new Error('Timeout waiting for signal');
}
```
