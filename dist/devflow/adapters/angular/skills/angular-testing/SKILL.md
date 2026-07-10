---
name: angular-testing
description: Angular v22+ unit + integration tests with Vitest. Use for component (signals, OnPush), service, HTTP, or routing tests. Triggers on test creation, mocking, or coverage tasks. Skip for E2E (Cypress/Playwright) or non-Angular code.
---

# Angular Testing

Test Angular v22+ with Vitest + TestBed. Focus: signal components, services, HTTP, router, async correctness.

## Testing Fundamentals (Zoneless Async-First)

Zoneless is stable default since v22 — async-first patterns below are baseline, not opt-in.

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

## Vitest Setup (Angular v22+)

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

## Coverage and Quality Rules

- Prefer behavior assertions over internal implementation assertions.
- Keep tests deterministic (no real network/time randomness).
- One behavior per test.
- Use fixture helpers for repetitive setup.

For advanced patterns — component harnesses (incl. `.with()` predicates), router testing, Cypress E2E conventions (`data-cy`, custom commands, element-wait), forms, directives, pipes — see [references/testing-patterns.md](references/testing-patterns.md).

## I/O Reference

|            |                                                                |
| ---------- | -------------------------------------------------------------- |
| Reads      | Active spec/test files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Vitest + TestBed spec files                  |
| Invoked by | `devflow.test`                                                 |
