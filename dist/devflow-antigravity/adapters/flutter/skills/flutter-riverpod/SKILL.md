---
name: flutter-riverpod
description: Use when implementing, refactoring, or debugging Flutter state management with Riverpod, especially for async state, invalidation/refresh, rebuild optimization, families, and provider testing.
---

# Skill: Flutter Riverpod

## Purpose

Riverpod 3 + riverpod_generator 4 providers, async UI through the project `.skeleton(mock:)` extension, invalidation and provider tests.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Choosing state scope (widget-local vs feature vs app-wide) before any provider exists → `common-state-patterns`
- Entity / DTO shape or `mock()` content → `flutter-models`
- Form field state inside a `FormBuilder` → `flutter-form`

## Rules

1. `@riverpod` codegen for every provider: functional (`Foo foo(Ref ref)`) or class (`extends _$Foo`). Generated typed refs (`FooRef`) removed — always plain `Ref`.
2. `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` live in `legacy.dart` — never use them in new code.
3. `AsyncValue.value` (null while loading/error); `valueOrNull` removed in Riverpod 3 — do not use it.
4. After every `await` in a notifier or provider: `if (!ref.mounted) return;` before touching `ref` or `state` (disposed `Ref` throws).
5. `ref.watch` to render, `ref.read` in callbacks, `ref.listen` for side effects (snackbar, navigation). Never `ref.read` in `build`.
6. `select` / `selectAsync` when only one field drives a rebuild.
7. Explicit invalidation after mutations: `ref.invalidateSelf()` in the same notifier, `ref.invalidate(other)` for dependents, `ref.refresh` for pull-to-refresh.
8. Auto-dispose default (generator default). `@Riverpod(keepAlive: true)` only for app-wide singletons (client, auth, router) or expensive caches; release with `onDispose`.
9. Family arguments stable + `==`-comparable (primitives, freezed classes).
10. State lives in providers — no duplicate mutable copy in widgets. Hooks (`HookConsumerWidget`) only for ephemeral widget state (controllers, focus, animation).

## Loading UI: `.skeleton(mock:)` (mandatory)

Every `AsyncValue` rendered in UI goes through the project extension — never `when(loading: …)` spinners or custom shimmers for content.

```dart
ref.watch(petsProvider).skeleton(
  mock: Pet.mockList(),               // from flutter-models — never inline fakes
  data: (pets) => PetListView(pets: pets),
  error: (e, st) => ErrorView(error: e),
);
```

- Extension lives in `lib/core/async/async_value_skeleton.dart`, exported by the `lib/core` barrel. **Missing → create it first** from [`references/riverpod-patterns.md`](references/riverpod-patterns.md) → `.skeleton` extension (built on `skeletonizer`).
- `data` builder runs once for both states: with `mock` while loading (skeletonized), with real data after.
- Inside slivers: `sliver: true`.
- Empty state handled inside `data` (empty list → empty view in slang copy).

## Testing

- Provider tests: `ProviderContainer.test(overrides: [...])` — auto-disposed, no manual `dispose`.
- Widget tests: `ProviderScope(overrides: [...])`; `tester.container()` for direct container access.
- Fakes via `repoProvider.overrideWithValue(FakeRepo())` — never real network.

Notifier, keepAlive and test code: [`references/riverpod-patterns.md`](references/riverpod-patterns.md). Riverpod APIs move between minors — check Context7 (`/rrousselgit/riverpod`) before writing an API not shown here.

## Anti-Patterns

| Avoid | Use instead |
| --- | --- |
| `ref.read` in `build` | `ref.watch(p.select(...))` |
| Mutation without invalidation | `invalidateSelf` / `invalidate(dependent)` |
| `ref` used after `await` without `ref.mounted` check | `if (!ref.mounted) return;` |
| `when(loading: CircularProgressIndicator…)` | `.skeleton(mock: Entity.mock())` |
| Business logic in widget callbacks | Notifier method → repository |

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `*/providers/*.dart`, `*_provider.dart`, `*_notifier.dart`, widgets rendering `AsyncValue` |
| Reads | `constitution.md` (Riverpod conventions), `registry.md` (provider patterns) |
| Invoked by | `devflow.plan` (Riverpod Providers section), `devflow.implement` (providers + async UI) |
| Related skills | `flutter-models` (`mock()`), `flutter-supabase` (repositories), `common-state-patterns` (scope choice) |
