---
name: angular-component
description: Create modern Angular standalone components following v22+ best practices. Use for building UI components with signal-based inputs/outputs, OnPush change detection, host bindings, content projection, and lifecycle hooks. Triggers on component creation, refactoring class-based inputs to signals, adding host bindings, or implementing accessible interactive components.
---

# Angular Component

Create standalone components for Angular v22+. Standalone default. Do NOT set `standalone: true`.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Component Structure

```typescript
import {
  Component,
  input,
  output,
  computed,
  booleanAttribute,
} from "@angular/core";

@Component({
  selector: "app-user-card",
  host: {
    class: "user-card",
    "[class.active]": "isActive()",
    "(click)": "handleClick()",
  },
  template: `
    <img [src]="avatarUrl()" [alt]="name() + ' avatar'" />
    <h2>{{ name() }}</h2>
    @if (showEmail()) {
      <p>{{ email() }}</p>
    }
  `,
  styles: `
    :host {
      display: block;
    }
    :host.active {
      border: 2px solid blue;
    }
  `,
})
export class UserCard {
  // Required input
  name = input.required<string>();

  // Optional inputs
  email = input<string>("");
  showEmail = input(false);

  // Input transform
  isActive = input(false, { transform: booleanAttribute });

  // Derived value
  avatarUrl = computed(() => `https://api.example.com/avatar/${this.name()}`);

  // Output
  selected = output<string>();

  handleClick() {
    this.selected.emit(this.name());
  }
}
```

`OnPush` is default change detection in v22+ — no explicit `changeDetection` needed.
`ChangeDetectionStrategy.Default` renamed `ChangeDetectionStrategy.Eager`. Set
`changeDetection: ChangeDetectionStrategy.Eager` only when component needs eager checks.

## Signal Inputs

```typescript
// Required. Parent must bind.
name = input.required<string>();

// Optional with default.
count = input(0);

// Optional, undefined allowed.
label = input<string>();

// Alias for template binding.
size = input("medium", { alias: "buttonSize" });

// Transform on read.
disabled = input(false, { transform: booleanAttribute });
value = input(0, { transform: numberAttribute });
```

## Signal Outputs

```typescript
import { output, outputFromObservable } from "@angular/core";
import { Subject } from "rxjs";

// Basic output
clicked = output<void>();
selected = output<Item>();

// Alias
valueChange = output<number>({ alias: "change" });

// Observable interop
scroll$ = new Subject<number>();
scrolled = outputFromObservable(this.scroll$);

// Emit
this.clicked.emit();
this.selected.emit(item);
```

## Two-Way Binding — `model()`

`model()` declares a writable signal input + companion output for `[(banana-in-box)]` syntax. Use for components that both receive and modify a value.

```typescript
@Component({
  selector: "app-counter",
  template: `<button (click)="value.set(value() + 1)">{{ value() }}</button>`,
})
export class Counter {
  // Generates `value` input + `valueChange` output automatically
  readonly value = model(0);
  readonly label = model.required<string>();
}
```

```html
<!-- Parent: two-way binds via [(value)] -->
<app-counter [(value)]="count" />
```

`model()` writes propagate to the bound parent signal — do NOT pair with a separate `output()` for the same value (redundant, fights the generated `*Change` output).

## Derived State — `computed()` vs `linkedSignal()`

`computed()`: pure derivation, read-only, recomputes on dependency change.
`linkedSignal()`: derived value that resets on source change BUT stays independently writable — use when a signal should track a source yet allow local overrides (e.g., selection resets when a list changes, but user can still pick within it).

```typescript
// Simple form — resets to source value whenever source changes
selectedTab = linkedSignal(() => this.tabs()[0]);

// Advanced form — explicit source + computation, preserves prior value when valid
selectedItem = linkedSignal<Item[], Item | undefined>({
  source: this.items,
  computation: (items, previous) =>
    items.find((i) => i.id === previous?.value?.id) ?? items[0],
});
```

Default to `computed()`. Reach for `linkedSignal()` only when the value must remain user-writable after being derived.

## Host Bindings

Use `host` object in `@Component`. Do NOT use `@HostBinding` or `@HostListener`.

```typescript
@Component({
  selector: "app-button",
  host: {
    // Static attrs
    role: "button",

    // Dynamic classes
    "[class.primary]": 'variant() === "primary"',
    "[class.disabled]": "disabled()",

    // Dynamic styles
    "[style.--btn-color]": "color()",

    // Attributes
    "[attr.aria-disabled]": "disabled()",
    "[attr.tabindex]": "disabled() ? -1 : 0",

    // Events
    "(click)": "onClick($event)",
    "(keydown.enter)": "onClick($event)",
    "(keydown.space)": "onClick($event)",
  },
  template: `<ng-content />`,
})
export class Button {
  variant = input<"primary" | "secondary">("primary");
  disabled = input(false, { transform: booleanAttribute });
  color = input("#007bff");

  clicked = output<void>();

  onClick(event: Event) {
    if (!this.disabled()) {
      this.clicked.emit();
    }
  }
}
```

## Reading Host Attributes — `HostAttributeToken`

Use `HostAttributeToken` to read a static attribute set on the host element at injection time — type-safe replacement for `@Attribute()`.

```typescript
import { inject, HostAttributeToken } from "@angular/core";

export class CustomInput {
  // Reads `type="..."` from host element; null if absent
  private type = inject(new HostAttributeToken("type"), { optional: true });
}
```

Use only for static, non-reactive host attributes known at element-creation time — for dynamic values, use `input()`/host bindings instead.

## Content Projection

```typescript
@Component({
  selector: "app-card",
  template: `
    <header>
      <ng-content select="[card-header]" />
    </header>
    <main>
      <ng-content />
    </main>
    <footer>
      <ng-content select="[card-footer]" />
    </footer>
  `,
})
export class Card {}

// Usage:
// <app-card>
//   <h2 card-header>Title</h2>
//   <p>Main content</p>
//   <button card-footer>Action</button>
// </app-card>
```

## Lifecycle Hooks

```typescript
import { OnDestroy, OnInit, afterNextRender, afterRender } from "@angular/core";

export class MyComponent implements OnInit, OnDestroy {
  constructor() {
    // Runs once after first render. SSR-safe.
    afterNextRender(() => {
      // Post-render setup
    });

    // Runs after every render.
    afterRender(() => {
      // Sync side effects
    });
  }

  ngOnInit() {
    // Init logic
  }

  ngOnDestroy() {
    // Cleanup logic
  }
}
```

### `afterRenderEffect()` — Phased Render Effects

Reactive version of `afterRender` — reruns when read signals change, runs in defined phases for safe DOM read/write ordering. SSR-safe (no-op on server).

```typescript
import { afterRenderEffect } from "@angular/core";

constructor() {
  afterRenderEffect({
    earlyRead: () => this.measureBeforeWrite(),       // read DOM before writes
    write: () => this.applyMeasurements(),            // write DOM
    mixedReadWrite: () => this.legacyLayoutThrash(),  // last resort — avoid
    read: () => this.reportFinalLayout(),             // read final layout
  });
}
```

Prefer splitting `earlyRead`/`write`/`read` over `mixedReadWrite` — phased separation avoids layout thrashing.

## `effect()` — Use Sparingly, Never for State Sync

**Never use `effect()` to sync one piece of state to another** — causes `ExpressionChangedAfterItHasBeenChecked` and creates hidden reactive chains. Use `computed()` or `linkedSignal()` instead.

```typescript
// WRONG — state-to-state sync via effect
effect(() => {
  this.fullName.set(`${this.first()} ${this.last()}`);
});

// RIGHT — pure derivation
fullName = computed(() => `${this.first()} ${this.last()}`);
```

`effect()` is for side effects with no reactive consumer: logging, localStorage sync, imperative third-party DOM/library integration. Always return a cleanup function for subscriptions/timers/listeners:

```typescript
effect((onCleanup) => {
  const id = setInterval(() => this.tick(), 1000);
  onCleanup(() => clearInterval(id));
});
```

## Accessibility Requirements

Components MUST:

- Pass AXE checks
- Meet WCAG AA
- Set correct ARIA for interactive UI
- Support keyboard navigation
- Keep visible focus indicators

```typescript
@Component({
  selector: "app-toggle",
  host: {
    role: "switch",
    "[attr.aria-checked]": "checked()",
    "[attr.aria-label]": "label()",
    tabindex: "0",
    "(click)": "toggle()",
    "(keydown.enter)": "toggle()",
    "(keydown.space)": "toggle(); $event.preventDefault()",
  },
  template: `<span class="toggle-track"
    ><span class="toggle-thumb"></span
  ></span>`,
})
export class Toggle {
  label = input.required<string>();
  checked = input(false, { transform: booleanAttribute });
  checkedChange = output<boolean>();

  toggle() {
    this.checkedChange.emit(!this.checked());
  }
}
```

## Template Syntax

Use native control flow. Do NOT use `*ngIf`, `*ngFor`, `*ngSwitch`.

```html
<!-- Conditionals -->
@if (isLoading()) {
<app-spinner />
} @else if (error()) {
<app-error [message]="error()" />
} @else {
<app-content [data]="data()" />
}

<!-- Loops -->
@for (item of items(); track item.id) {
<app-item [item]="item" />
} @empty {
<p>No items found</p>
}

<!-- Switch: multiple cases share one output -->
@switch (status()) {
  @case ('pending'), @case ('active') { <span>In progress</span> }
  @case ('done') { <span>Done</span> }
  @default { <span>Unknown</span> }
}

<!-- Switch: exhaustive check on union type — @default never errors at compile time
     when a case is missing -->
@switch (role()) {
  @case ('admin') { <app-admin-panel /> }
  @case ('member') { <app-member-panel /> }
  @default never
}
```

## Inline Functions and Spread (v22+)

Arrow functions and spread/rest syntax are valid directly in templates.

```html
<!-- Arrow functions inline -->
@for (item of items(); track item.id) {
<app-item [item]="item" (click)="(() => select(item))()" />
}
<button (click)="((e) => handleClick(e, item))($event)">Select</button>

<!-- Spread in object/array literals and calls -->
<app-user-card [config]="{ ...baseConfig(), highlighted: isActive() }" />
<app-tag-list [tags]="[...defaultTags(), ...customTags()]" />
<app-form [errors]="mergeErrors(...errorSources())" />
```

## Class and Style Bindings

Do NOT use `ngClass` or `ngStyle`. Use direct bindings.

```html
<!-- Class bindings -->
<div [class.active]="isActive()">Single class</div>
<div [class]="classString()">Class string</div>

<!-- Style bindings -->
<div [style.color]="textColor()">Styled text</div>
<div [style.width.px]="width()">With unit</div>
```

## Images

Use `NgOptimizedImage` for static images.

```typescript
import { NgOptimizedImage } from "@angular/common";

@Component({
  imports: [NgOptimizedImage],
  template: `
    <img ngSrc="/assets/hero.jpg" width="800" height="600" priority />
    <img [ngSrc]="imageUrl()" width="200" height="200" />
  `,
})
export class Hero {
  imageUrl = input.required<string>();
}
```

For advanced patterns, see [references/component-patterns.md](references/component-patterns.md).

## I/O Reference

|            |                                                                |
| ---------- | -------------------------------------------------------------- |
| Reads      | Active component files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular standalone component files           |
| Invoked by | `devflow.implement`, `devflow.beautify`                        |
