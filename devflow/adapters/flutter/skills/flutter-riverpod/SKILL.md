---
name: flutter-riverpod
description: Use when implementing, refactoring, or debugging Flutter state management with Riverpod, especially for async state, invalidation/refresh, rebuild optimization, families, and provider testing.
---

# Flutter Riverpod Expert

## Overview

Use Riverpod v3 patterns for predictable, testable, performant state.
Prefer `@riverpod` codegen + explicit invalidation.

## When to Use

- Building features with Riverpod in Flutter.
- Fixing stale UI, over-rebuilds, or wrong provider lifecycle behavior.
- Designing async fetch + mutation flows.
- Testing providers/widgets with overrides.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Core Rules

1. Prefer `@riverpod` code generation for type-safe providers.
2. Keep a single source of truth in providers (avoid duplicated mutable widget state).
3. In UI, use `ref.watch` for rendering, `ref.read` for actions, `ref.listen` for side effects.
4. Use `select`/`selectAsync` when only a sub-field should trigger rebuilds.
5. Make invalidation strategy explicit (`invalidate`, `refresh`, `invalidateSelf`).
6. **Loading UI must use the `skeleton` extension** on `AsyncValue` (never `when(loading: …)` spinners/shimmers for content).
7. **Skeleton mock lives on the entity** — pass `Entity.placeholder()` (or a list of them) as `mock:`; never inline ad-hoc fake data in widgets.

## Provider Selection

- **`Provider`**: immutable/computed values.
- **`NotifierProvider`**: mutable synchronous state.
- **`AsyncNotifierProvider`**: async state + mutations in one unit (recommended default for async features).
- **`FutureProvider`**: read-only async computation.
- **`StreamProvider`**: true real-time streams.
- **Families**: parameterized providers; arguments must be stable/equatable.

## Minimal Patterns

### Sync state with Notifier

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'counter.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}
```

### Async fetch + mutation

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'todos.g.dart';

@riverpod
class Todos extends _$Todos {
  @override
  Future<List<Todo>> build() async {
    return ref.watch(todoRepositoryProvider).fetchTodos();
  }

  Future<void> addTodo(String title) async {
    final repo = ref.read(todoRepositoryProvider);
    await repo.createTodo(title);
    ref.invalidateSelf();
  }
}
```

### UI consumption (skeleton loading)

Use the project `skeleton` extension on `AsyncValue` — it skeletonizes the **same** `data` builder with `mock` while loading, then animates to real data.

```dart
class TodoPage extends ConsumerWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(todosProvider);

    ref.listen(todosProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.toString())),
          );
        },
      );
    });

    return todos.skeleton(
      mock: Todo.placeholderList(), // static on Todo entity — see flutter-models
      data: (items) => ListView(
        children: [for (final t in items) TodoTile(todo: t)],
      ),
      error: (e, _) => ErrorView(error: e),
    );
  }
}
```

Single-entity provider: `mock: Pet.placeholder()`. List provider: `mock: Todo.placeholderList()` (or fixed-length list factory on the entity).

Entity placeholder contract: see `flutter-models` (`placeholder()` factory on entities used in skeleton UI).

## Loading UI: `skeleton` extension (mandatory)

For any `AsyncValue<T>` rendered in UI:

- **Always** call `.skeleton(...)`, not `.when(loading: …)`.
- **`data`**: build the real loaded UI once; extension reuses it for loading (with `Skeletonizer` enabled) and data (disabled, with switch animation).
- **`mock`**: value of type `T` from the domain entity (`Entity.placeholder()` or `Entity.placeholderList()`). Keeps skeleton shape aligned with real widgets and centralized.
- **`error`**: dedicated error UI; optional `skipError` / `skipLoadingOnReload` / `skipLoadingOnRefresh` only when UX requires it.

```dart
ref.watch(petProvider).skeleton(
  mock: Pet.placeholder(),
  data: (pet) => PetDetailBody(pet: pet),
  error: (e, st) => PetErrorView(error: e, stackTrace: st),
);
```

Do **not**:

- Hand-roll `Skeletonizer` around loading branches in widgets.
- Put fake strings/IDs/colors in the widget for loading.
- Use `CircularProgressIndicator` / generic shimmer where the loaded layout is known.

`AsyncSnapshot` has the same `skeleton` extension (e.g. `FutureBuilder`); use `sliver: true` inside sliver lists.

## `watch` vs `read` vs `listen` vs `select`

- **`watch`**: reactive read for rendering/derived logic.
- **`read`**: one-shot read for callbacks/commands.
- **`listen`**: side effects on transitions (snackbar, navigation).
- **`select`**: rebuild only on selected field changes.

Bad:

```dart
final value = ref.read(userProvider); // in build: UI won't react to updates
```

Good:

```dart
final userName = ref.watch(userProvider.select((u) => u.name));
```

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

```dart
@riverpod
Future<String> cachedValue(Ref ref) async {
  final value = await fetchValue();
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return value;
}
```

## Testing

### Provider tests

```dart
test('counter increments', () {
  final container = ProviderContainer.test();
  addTearDown(container.dispose);

  expect(container.read(counterProvider), 0);
  container.read(counterProvider.notifier).increment();
  expect(container.read(counterProvider), 1);
});
```

### Overrides

```dart
final container = ProviderContainer.test(
  overrides: [
    todoRepositoryProvider.overrideWithValue(FakeTodoRepository()),
  ],
);
```

### Widget tests

- Wrap with `ProviderScope`.
- Inject fakes with overrides.
- Use `tester.container()` when direct container access is needed.

## Common Anti-Patterns

- Using `read` in `build` to avoid rebuilds.
- Keeping duplicated mutable state in widget + provider.
- Mutations without invalidation/refresh of dependent providers.
- Watching entire objects when only one field is needed.
- Business logic in widgets instead of provider/repository layer.
- `AsyncValue.when(loading: CircularProgressIndicator…)` or custom loading widgets instead of `.skeleton`.
- Inline skeleton mocks in widgets instead of `Entity.placeholder()` on the domain model.

## I/O Reference

|                |                                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------- |
| Trigger        | Implementing or debugging Riverpod providers, notifiers, async state, or families                                   |
| Reads          | `constitution.md` (Riverpod conventions), `registry.md` (existing provider patterns)                                |
| Invoked by     | `devflow.plan` (Riverpod Providers section), `devflow.implement` (provider/notifier files)                          |
| Related skills | `flutter-models` (domain entities consumed by providers), `flutter-supabase` (repository layer called by notifiers) |

## Pre-Ship Checklist

- [ ] Correct provider type selected.
- [ ] Async UI uses `.skeleton` with entity `placeholder()` as `mock` (no manual loading spinners).
- [ ] `watch/read/listen/select` used intentionally.
- [ ] Invalidation strategy documented in code.
- [ ] Family arguments stable/equatable.
- [ ] Providers tested with `ProviderContainer.test` and overrides.
- [ ] No obvious rebuild hot spots.
