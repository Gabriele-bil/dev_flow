---
name: flutter-riverpod
description: Use when implementing, refactoring, or debugging Flutter state management with Riverpod, especially for async state, invalidation/refresh, rebuild optimization, families, and provider testing.
---

# Flutter Riverpod Expert

## Overview

Use Riverpod v3 patterns for predictable, testable, performant state.
Prefer `@riverpod` codegen + explicit invalidation.

Full code: `references/riverpod-patterns.md`.

## When to Use

- Building features with Riverpod in Flutter.
- Fixing stale UI, over-rebuilds, or wrong provider lifecycle behavior.
- Designing async fetch + mutation flows.
- Testing providers/widgets with overrides.

## Core Rules

1. Prefer `@riverpod` code generation for type-safe providers.
2. Keep a single source of truth in providers (avoid duplicated mutable widget state).
3. In UI, use `ref.watch` for rendering, `ref.read` for actions, `ref.listen` for side effects.
4. Use `select`/`selectAsync` when only a sub-field should trigger rebuilds.
5. Make invalidation strategy explicit (`invalidate`, `refresh`, `invalidateSelf`).
6. **Loading UI must use the `skeleton` extension** on `AsyncValue` (never `when(loading: …)` spinners/shimmers for content).
7. **Skeleton mock lives on the entity** — pass `Entity.mock()` (or `Entity.mockList()`) as `mock:`; never inline ad-hoc fake data in widgets.

## Provider Selection

- **`Provider`**: immutable/computed values.
- **`NotifierProvider`**: mutable synchronous state.
- **`AsyncNotifierProvider`**: async state + mutations in one unit (recommended default for async features).
- **`FutureProvider`**: read-only async computation.
- **`StreamProvider`**: true real-time streams.
- **Families**: parameterized providers; arguments must be stable/equatable.

## Loading UI: `skeleton` extension (mandatory)

For any `AsyncValue<T>` rendered in UI:

- **Always** call `.skeleton(...)`, not `.when(loading: …)`.
- **`data`**: build the real loaded UI once; extension reuses it for loading (with `Skeletonizer` enabled) and data (disabled, with switch animation).
- **`mock`**: `Entity.mock()` / `Entity.mockList()` from the domain entity — never inline fakes.

## `watch` / `read` / `listen` / `select`

- **`watch`**: reactive read for rendering/derived logic.
- **`read`**: one-shot read for callbacks/commands.
- **`listen`**: side effects on transitions (snackbar, navigation).
- **`select`**: rebuild only on selected field changes.

`ref.read` inside `build` is an anti-pattern — UI won't react to updates. Use `ref.watch(provider.select(...))` instead.

## Invalidation Semantics

- **`ref.invalidate(provider)`**: mark stale; recompute when read next.
- **`ref.refresh(provider)`**: invalidate + immediate read.
- **`ref.invalidateSelf()`**: invalidate current provider/notifier.

Use:

- After a mutation in the same notifier: `invalidateSelf`.
- Pull-to-refresh action: `refresh`.
- External cache dependency changed: `invalidate(targetProvider)`.

## Lifecycle: autoDispose and keepAlive

- Prefer auto-dispose for screen-scoped state.
- Use keep-alive only for expensive/UX-critical caches.
- Manage resources with `onDispose` and related lifecycle hooks.

## Testing

- Provider tests: `ProviderContainer.test()`, `addTearDown(container.dispose)`.
- Overrides: `provider.overrideWithValue(fake)`.
- Widget tests: wrap with `ProviderScope`, inject fakes via overrides, use `tester.container()` when direct access is needed.

## Common Anti-Patterns

- Using `read` in `build` to avoid rebuilds.
- Keeping duplicated mutable state in widget + provider.
- Mutations without invalidation/refresh of dependent providers.
- Watching entire objects when only one field is needed.
- Business logic in widgets instead of provider/repository layer.
- `AsyncValue.when(loading: CircularProgressIndicator…)` or custom loading widgets instead of `.skeleton`.
- Inline skeleton mocks in widgets instead of `Entity.mock()` on the domain model.

## I/O Reference

|                |                                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------- |
| Trigger        | Implementing or debugging Riverpod providers, notifiers, async state, or families                                   |
| Reads          | `constitution.md` (Riverpod conventions), `registry.md` (existing provider patterns)                                |
| Invoked by     | `devflow.plan` (Riverpod Providers section), `devflow.implement` (provider/notifier files)                          |
| Related skills | `flutter-models` (domain entities consumed by providers), `flutter-supabase` (repository layer called by notifiers) |

## Pre-Ship Checklist

- [ ] Correct provider type selected.
- [ ] Async UI uses `.skeleton` with `Entity.mock()` / `mockList()` as `mock:` (no manual loading spinners).
- [ ] `watch/read/listen/select` used intentionally.
- [ ] Invalidation strategy documented in code.
- [ ] Family arguments stable/equatable.
- [ ] Providers tested with `ProviderContainer.test` and overrides.
- [ ] No obvious rebuild hot spots.
