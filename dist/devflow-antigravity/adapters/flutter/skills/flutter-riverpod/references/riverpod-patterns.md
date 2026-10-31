# Flutter Riverpod — Code Patterns

Rules live in `../SKILL.md`; this file holds the code the project creates once or copies per feature.

## `.skeleton` extension (create once)

`lib/core/async/async_value_skeleton.dart` — needs `skeletonizer` (installed by `devflow.setup`). Export it from the `lib/core` barrel.

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

extension AsyncValueSkeleton<T> on AsyncValue<T> {
  /// Renders [data] with [mock] while loading (skeletonized), real data after.
  Widget skeleton({
    required T mock,
    required Widget Function(T value) data,
    required Widget Function(Object error, StackTrace stackTrace) error,
    bool sliver = false,
  }) {
    Widget wrap(bool loading, Widget child) => sliver
        ? Skeletonizer.sliver(enabled: loading, child: child)
        : Skeletonizer(
            enabled: loading,
            enableSwitchAnimation: true,
            child: child,
          );

    return when(
      data: (value) => wrap(false, data(value)),
      loading: () => wrap(true, data(mock)),
      error: error,
    );
  }
}
```

`when` keeps previous data on refresh (`skipLoadingOnRefresh` defaults to `true`), so pull-to-refresh does not flash the skeleton.

## Async notifier with mutation

```dart
@riverpod
class Pets extends _$Pets {
  @override
  Future<List<Pet>> build() =>
      ref.watch(petRepositoryProvider).list().then((r) => switch (r) {
            Ok(:final value) => value,
            Err(:final error) => throw error,
          });

  Future<void> add(Pet pet) async {
    await ref.read(petRepositoryProvider).create(pet);
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}
```

## Side effects with `ref.listen`

```dart
ref.listen(petsProvider, (prev, next) {
  if (next case AsyncError(:final error)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
});
```

## Timed cache with keepAlive

```dart
@riverpod
Future<Config> remoteConfig(Ref ref) async {
  final value = await fetchConfig();
  if (!ref.mounted) return value;
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return value;
}
```

## Tests

```dart
test('add invalidates the list', () async {
  final container = ProviderContainer.test(
    overrides: [petRepositoryProvider.overrideWithValue(FakePetRepository())],
  );
  await container.read(petsProvider.future);
  await container.read(petsProvider.notifier).add(Pet.mock());
  expect(await container.read(petsProvider.future), hasLength(1));
});
```
