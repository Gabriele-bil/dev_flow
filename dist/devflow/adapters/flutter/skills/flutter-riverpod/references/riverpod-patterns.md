# Flutter Riverpod — Code Patterns

## Sync state with Notifier

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

## Async fetch + mutation

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

## UI consumption (skeleton loading)

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
      mock: Todo.mockList(), // on Todo entity — see flutter-models
      data: (items) => ListView(
        children: [for (final t in items) TodoTile(todo: t)],
      ),
      error: (e, _) => ErrorView(error: e),
    );
  }
}
```

Single-entity provider: `mock: Pet.mock()`. List provider: `mock: Todo.mockList()`.

Entity mock contract: see `flutter-models` (`mock()` / `mockList()` on domain entities).

## `skeleton` extension example

```dart
ref.watch(petProvider).skeleton(
  mock: Pet.mock(),
  data: (pet) => PetDetailBody(pet: pet),
  error: (e, st) => PetErrorView(error: e, stackTrace: st),
);
```

`AsyncSnapshot` has the same `skeleton` extension (e.g. `FutureBuilder`); use `sliver: true` inside sliver lists.

## `watch` vs `read` in build

Bad:

```dart
final value = ref.read(userProvider); // in build: UI won't react to updates
```

Good:

```dart
final userName = ref.watch(userProvider.select((u) => u.name));
```

## Lifecycle: keepAlive

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
