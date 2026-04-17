---
name: flutter-riverpod
description: Use when implementing, refactoring, or debugging Flutter state management with Riverpod, especially for async state, invalidation/refresh, rebuild optimization, families, and provider testing.
---

# Flutter Riverpod Expert

## Overview
Use Riverpod v3-style patterns to keep state predictable, testable, and performant.
Prefer `@riverpod` code generation and explicit invalidation rules.

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

### UI consumption
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

    return todos.when(
      data: (items) => ListView(children: [for (final t in items) Text(t.title)]),
      loading: CircularProgressIndicator.new,
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

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

## I/O Reference

| | |
|---|---|
| Trigger | Implementing or debugging Riverpod providers, notifiers, async state, or families |
| Reads | `constitution.md` (Riverpod conventions), `registry.md` (existing provider patterns) |
| Invoked by | `devflow.plan` (Riverpod Providers section), `devflow.implement` (provider/notifier files) |
| Related skills | `flutter-models` (domain entities consumed by providers), `flutter-supabase` (repository layer called by notifiers) |

## Pre-Ship Checklist
- [ ] Correct provider type selected.
- [ ] Async UI handles loading/data/error explicitly.
- [ ] `watch/read/listen/select` used intentionally.
- [ ] Invalidation strategy documented in code.
- [ ] Family arguments stable/equatable.
- [ ] Providers tested with `ProviderContainer.test` and overrides.
- [ ] No obvious rebuild hot spots.
