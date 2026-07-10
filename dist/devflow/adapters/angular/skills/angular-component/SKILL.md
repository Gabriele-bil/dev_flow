---
name: angular-component
description: Angular v22+ standalone components — signal inputs/outputs, OnPush, host bindings, content projection, lifecycle hooks. Triggers on component creation, input→signal refactor, or host binding work.
---

# Angular Component

Standalone is the default in v22+ — do NOT set `standalone: true`. `OnPush` is default change detection — no explicit `changeDetection` needed. `ChangeDetectionStrategy.Default` renamed `ChangeDetectionStrategy.Eager`; set it only when a component needs eager checks.

## Rules

- **Signal inputs/outputs**: use `input()`, `input.required()`, `output()` over decorators.
- **`model()`**: writable signal input + companion output for `[(banana-in-box)]` two-way binding. Writes propagate to the bound parent signal — do NOT pair with a separate `output()` for the same value.
- **`computed()` vs `linkedSignal()`**: default to `computed()` (pure, read-only). Use `linkedSignal()` only when a derived value must reset on source change but stay independently writable (e.g., selection resets when a list changes, but the user can still pick within it).
- **Host bindings**: use the `host` object in `@Component`. Do NOT use `@HostBinding` or `@HostListener`.
- **`HostAttributeToken`**: type-safe replacement for `@Attribute()` to read a static host attribute at injection time. Use only for static, non-reactive attributes known at element-creation time — for dynamic values use `input()`/host bindings instead.
- **`effect()`**: use sparingly, never for state sync. Syncing one signal to another via `effect()` causes `ExpressionChangedAfterItHasBeenChecked` and hidden reactive chains — use `computed()`/`linkedSignal()` instead. Reserve `effect()` for side effects with no reactive consumer (logging, localStorage sync, imperative DOM/third-party integration); always return a cleanup function for subscriptions/timers/listeners.
- **Template syntax**: use native control flow (`@if`, `@for`, `@switch`). Do NOT use `*ngIf`, `*ngFor`, `*ngSwitch`.
- **Inline functions and spread (v22+)**: arrow functions and spread/rest syntax are valid directly in templates.
- **Class/style bindings**: use `[class.x]`, `[class]`, `[style.x]` directly. Do NOT use `ngClass`/`ngStyle`.
- **Images**: use `NgOptimizedImage` (`ngSrc`) for static and dynamic images.

## Accessibility Requirements

Components MUST:

- Pass AXE checks
- Meet WCAG AA
- Set correct ARIA for interactive UI
- Support keyboard navigation
- Keep visible focus indicators

Full code (component structure, signal inputs/outputs, model(), computed/linkedSignal, host bindings, HostAttributeToken, content projection, lifecycle hooks, afterRenderEffect(), effect(), accessible toggle example, template syntax, inline functions/spread, class/style bindings, images, plus advanced patterns) → [references/component-patterns.md](references/component-patterns.md).

## I/O Reference

|            |                                                                |
| ---------- | -------------------------------------------------------------- |
| Reads      | Active component files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular standalone component files           |
| Invoked by | `devflow.implement`, `devflow.beautify`                        |
