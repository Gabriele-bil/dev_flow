---
name: angular-testing
description: Write unit and integration tests for Angular v20+ applications using Vitest with TestBed and modern testing patterns. Use for testing components with signals, OnPush change detection, services with inject(), HTTP interactions, and router flows. Triggers on test creation, mocking dependencies, testing signal-based behavior, or setting up Angular test infrastructure. Don't use for E2E testing with Cypress or Playwright, or for non-Angular JavaScript/TypeScript code.
---

# Angular Testing

Test Angular v20+ with Vitest + TestBed. Focus: signal components, services, HTTP, router, async correctness.

## Testing Fundamentals (Zoneless Async-First)

Default pattern: **Act -> Wait -> Assert**.

- Act: update input/state or trigger event
- Wait: `await fixture.whenStable()`
- Assert: check DOM/state

Do not use `fixture.detectChanges()` as main trigger for state propagation. Use it only when needed for explicit DOM sync checks.

```typescript
import { ComponentFixture, TestBed } from "@angular/core/testing";
import { MyComponent } from "./my.component";

describe("MyComponent", () => {
  let fixture: ComponentFixture<MyComponent>;
  let component: MyComponent;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MyComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(MyComponent);
    component = fixture.componentInstance;
  });

  it("updates title", async () => {
    component.title.set("New title");
    await fixture.whenStable();
    expect(fixture.nativeElement.textContent).toContain("New title");
  });
});
```

## Vitest Setup (Angular v20+)

Angular v20+ supports unit-test builder in `@angular/build`.

```bash
npm install -D vitest jsdom
```

```json
{
  "projects": {
    "your-app": {
      "architect": {
        "test": {
          "builder": "@angular/build:unit-test",
          "options": {
            "tsConfig": "tsconfig.spec.json",
            "buildTarget": "your-app:build"
          }
        }
      }
    }
  }
}
```

```bash
ng test
ng test --watch
ng test --code-coverage
```

## Basic Component Test

```typescript
import { describe, it, expect, beforeEach } from "vitest";
import { ComponentFixture, TestBed } from "@angular/core/testing";
import { CounterComponent } from "./counter.component";

describe("CounterComponent", () => {
  let component: CounterComponent;
  let fixture: ComponentFixture<CounterComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CounterComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(CounterComponent);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it("creates component", () => {
    expect(component).toBeTruthy();
  });

  it("increments count", async () => {
    expect(component.count()).toBe(0);
    component.increment();
    await fixture.whenStable();
    expect(component.count()).toBe(1);
  });
});
```

## Testing Signals

### Direct Signal Logic

```typescript
import { computed, signal } from "@angular/core";

it("updates computed from signal changes", () => {
  const count = signal(0);
  const doubled = computed(() => count() * 2);

  expect(doubled()).toBe(0);
  count.set(5);
  expect(doubled()).toBe(10);
  count.update((v) => v + 1);
  expect(doubled()).toBe(12);
});
```

### Component Signal State

```typescript
it("filters active todos", async () => {
  const fixture = TestBed.createComponent(TodoListComponent);
  const component = fixture.componentInstance;

  component.todos.set([
    { id: "1", text: "A", done: false },
    { id: "2", text: "B", done: true },
    { id: "3", text: "C", done: false },
  ]);
  component.filter.set("active");

  await fixture.whenStable();
  expect(component.filteredTodos().length).toBe(2);
  expect(component.remaining()).toBe(2);
});
```

## Testing OnPush Components

For signal inputs use `setInput`, then wait for stability.

```typescript
it("updates OnPush template after input change", async () => {
  const fixture = TestBed.createComponent(OnPushComponent);

  fixture.componentRef.setInput("data", { name: "Initial" });
  await fixture.whenStable();
  expect(fixture.nativeElement.textContent).toContain("Initial");

  fixture.componentRef.setInput("data", { name: "Updated" });
  await fixture.whenStable();
  expect(fixture.nativeElement.textContent).toContain("Updated");
});
```

## Testing Services

### Basic Service

```typescript
describe("CounterService", () => {
  let service: CounterService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(CounterService);
  });

  it("increments", () => {
    expect(service.count()).toBe(0);
    service.increment();
    expect(service.count()).toBe(1);
  });
});
```

### Service with HTTP

```typescript
import { provideHttpClient } from "@angular/common/http";
import {
  HttpTestingController,
  provideHttpClientTesting,
} from "@angular/common/http/testing";

describe("UserService", () => {
  let service: UserService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(UserService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it("fetches user by id", () => {
    const mockUser = { id: "1", name: "Test User" };

    service.getUser("1").subscribe((user) => expect(user).toEqual(mockUser));

    const req = httpMock.expectOne("/api/users/1");
    expect(req.request.method).toBe("GET");
    req.flush(mockUser);
  });
});
```

## Mocking Dependencies (Vitest)

Use `vi.fn`, `vi.spyOn`, `vi.mock`.

```typescript
import { describe, it, expect, beforeEach, vi } from "vitest";
import { of } from "rxjs";

describe("UserProfileComponent", () => {
  const mockUserService = {
    getUser: vi.fn(),
    updateUser: vi.fn(),
    user: signal<User | null>(null),
  };

  beforeEach(async () => {
    vi.clearAllMocks();
    mockUserService.getUser.mockReturnValue(of({ id: "1", name: "Test" }));

    await TestBed.configureTestingModule({
      imports: [UserProfileComponent],
      providers: [{ provide: UserService, useValue: mockUserService }],
    }).compileComponents();
  });

  it("calls getUser on init", async () => {
    const fixture = TestBed.createComponent(UserProfileComponent);
    await fixture.whenStable();
    expect(mockUserService.getUser).toHaveBeenCalledWith("1");
  });
});
```

## Testing Inputs and Outputs

```typescript
it("emits selected event on click", async () => {
  const fixture = TestBed.createComponent(ItemComponent);
  const item: Item = { id: "1", name: "Test Item" };

  fixture.componentRef.setInput("item", item);
  await fixture.whenStable();

  let emitted: Item | undefined;
  fixture.componentInstance.selected.subscribe((v) => (emitted = v));

  fixture.nativeElement.querySelector("div").click();
  await fixture.whenStable();

  expect(emitted).toEqual(item);
});
```

## Testing Async Operations

### `fakeAsync`

```typescript
import { fakeAsync, flush, tick } from "@angular/core/testing";

it("debounces search", fakeAsync(() => {
  const fixture = TestBed.createComponent(SearchComponent);
  fixture.componentInstance.query.set("test");

  tick(300);
  flush();

  expect(fixture.componentInstance.results().length).toBeGreaterThan(0);
}));
```

### `waitForAsync`

```typescript
import { waitForAsync } from "@angular/core/testing";

it("loads async data", waitForAsync(async () => {
  const fixture = TestBed.createComponent(DataComponent);
  await fixture.whenStable();
  expect(fixture.componentInstance.data()).toBeDefined();
}));
```

## Testing HTTP Resources

```typescript
describe("UserComponent", () => {
  let httpMock: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();

    httpMock = TestBed.inject(HttpTestingController);
  });

  it("renders user after httpResource resolves", async () => {
    const fixture = TestBed.createComponent(UserComponent);
    await fixture.whenStable();

    const req = httpMock.expectOne("/api/users/1");
    req.flush({ id: "1", name: "John Doe" });

    await fixture.whenStable();
    expect(fixture.nativeElement.textContent).toContain("John Doe");
  });
});
```

## Coverage and Quality Rules

- Prefer behavior assertions over internal implementation assertions.
- Keep tests deterministic (no real network/time randomness).
- One behavior per test.
- Use fixture helpers for repetitive setup.

For advanced patterns (harness, router, forms, directives, pipes), see [references/testing-patterns.md](references/testing-patterns.md).

## I/O Reference

|            |                                                                |
| ---------- | -------------------------------------------------------------- |
| Reads      | Active spec/test files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Vitest + TestBed spec files                  |
| Invoked by | `devflow.test`                                                 |
