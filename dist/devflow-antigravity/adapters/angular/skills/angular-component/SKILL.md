---
name: angular-component
description: Angular v22+ standalone components — signal inputs/outputs, OnPush, host bindings, content projection, lifecycle hooks. Triggers on component creation, input→signal refactor, or host binding work.
---

# Angular Component

## Purpose

Write Angular v22 standalone components: signal APIs, default `OnPush`, `host` metadata, native control flow.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no component/template touched).
- Form fields and validation → `angular-forms`; accessible composite widgets → `angular-aria`.
- Stylesheet/theme tokens only → `angular-theme`.

## Rules

- **Defaults**: do not use `standalone: true`, omit `changeDetection` — standalone + `OnPush` are v22 defaults. `ChangeDetectionStrategy.Eager` (renamed from `Default`) only when a component truly needs eager checks.
- **Signal APIs**: `input()`, `input.required()`, `output()`, `model()` for two-way binding (no extra `output()` for the same value), `viewChild()`/`contentChildren()` queries.
- **Derived state**: `computed()` by default; `linkedSignal()` when derived value must stay writable. Never `effect()` to sync one signal into another.
- **`effect()`**: only for non-signal sinks (logging, localStorage, third-party DOM), with cleanup.
- **Host**: `host: {}` metadata. Do not use `@HostBinding`/`@HostListener`. Static host attribute → `HostAttributeToken`.
- **Templates**: `@if`/`@for` (with `track`)/`@switch` — do not use `*ngIf`/`*ngFor`/`*ngSwitch`. `[class.x]`/`[style.x]` instead of `ngClass`/`ngStyle`.
- **Images**: `NgOptimizedImage` (`ngSrc`).
- **No HTTP** in components — read state signals (`angular-http`, `angular-architecture`).

## Accessibility Requirements

Pass AXE, meet WCAG AA, correct ARIA on interactive UI, keyboard support, visible focus.

Detail (linkedSignal forms, render hooks, `@switch` patterns, template expression limits): [references/component-patterns.md](references/component-patterns.md).

## I/O Reference

|            |                                                                |
| ---------- | -------------------------------------------------------------- |
| Reads      | Active component files, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular standalone component files           |
| Invoked by | `devflow.implement`, `devflow.beautify`                        |
