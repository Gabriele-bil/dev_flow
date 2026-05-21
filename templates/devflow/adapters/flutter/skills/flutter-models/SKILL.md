---
name: flutter-models
description: Use when creating or refactoring Flutter domain entities, DTOs, enums, failures, and repository contracts. Applies to Freezed/json_serializable model design, JSON mapping boundaries, and immutable data patterns.
---

# Skill: Flutter Models

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Core Rules

- Keep all models immutable (`final` fields, no setters, update with `copyWith`).
- Keep boundaries strict: domain has no JSON/Supabase concerns; data layer handles wire format.
- Prefer explicit class modifiers:
  - `@freezed class` for concrete immutable entities/DTOs.
  - `@freezed sealed class` for union/failure/result states.
  - `abstract interface class` for repository contracts.
  - `final class` for concrete implementations you do not want externally subtype-able.

## Why Not Abstract Entities?

Entities/DTOs should usually be concrete immutable value types, not abstract classes.  
Use abstraction for behavior contracts (`abstract interface class PetRepository`), not data containers.

## Required Setup

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pet.freezed.dart';
part 'pet.g.dart'; // only when using fromJson/toJson
```

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use `watch` during heavy modeling work:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Entity (Domain)

Lives in `domain/`. Represents business meaning only.

```dart
@freezed
class Pet with _$Pet {
  const Pet._();

  const factory Pet({
    required String id,
    required String name,
    required PetSpecies species,
    required DateTime birthDate,
    required bool isNeutered,
    String? breed,
    String? microchip,
    String? photoUrl,
    double? initialWeight,
  }) = _Pet;

  /// Skeleton loading data — passed as `mock:` to `AsyncValue.skeleton`.
  factory Pet.mock() => Pet(
    id: 'mock-id',
    name: 'Mock pet name',
    species: PetSpecies.dog,
    birthDate: DateTime(2020, 1, 1),
    isNeutered: false,
    breed: 'Mock breed',
    microchip: null,
    photoUrl: null,
    initialWeight: 12.5,
  );

  static List<Pet> mockList({int count = 3}) =>
      List.generate(count, (_) => Pet.mock());

  int get ageInYears => DateTime.now().difference(birthDate).inDays ~/ 365;
}
```

Notes:

- Keep JSON methods out of entities.
- Add private constructor (`const Pet._()`) when the entity has custom getters/methods **or** `mock()`.
- Add `mock()` (and `mockList()` when listed in skeleton UI) only on entities actually used with `.skeleton`.

## Skeleton `mock()` (domain)

Lives on the entity in `domain/`. Single source of truth for loading-state data consumed by `AsyncValue.skeleton` / `AsyncSnapshot.skeleton` (`mock:` parameter).

Rules:

- **Name**: `factory Entity.mock()` — never `placeholder()` or widget-local fakes.
- **Shape**: realistic field lengths and non-null values where the loaded UI expects them; skeletonizer masks content, layout must match real data.
- **Lists**: `static List<Entity> mockList({int count = 3})` on the same entity class.
- **Scope**: domain only — no `mock()` on DTOs.

Wiring in UI (see `flutter-riverpod`):

```dart
ref.watch(petProvider).skeleton(
  mock: Pet.mock(),
  data: (pet) => PetDetailBody(pet: pet),
  error: (e, st) => PetErrorView(error: e, stackTrace: st),
);

ref.watch(petsProvider).skeleton(
  mock: Pet.mockList(),
  data: (pets) => PetListView(pets: pets),
  error: (e, st) => PetErrorView(error: e, stackTrace: st),
);
```

## DTO (Data Transfer Object)

Lives in `data/`. Maps the transport/storage schema.

```dart
@freezed
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class PetDto with _$PetDto {
  const factory PetDto({
    required String id,
    required String name,
    required String species,
    required String birthDate,
    required bool isNeutered,
    String? breed,
    String? microchip,
    String? photoUrl,
    double? initialWeight,
    required String createdAt,
    required String updatedAt,
  }) = _PetDto;

  factory PetDto.fromJson(Map<String, dynamic> json) => _$PetDtoFromJson(json);
}
```

Use `@JsonKey(...)` when one field needs custom behavior (rename, conversion, required/default):

```dart
@JsonKey(name: 'birth_date', fromJson: _fromIso, toJson: _toIso)
final DateTime birthDate;
```

## Mapper (Boundary Adapter)

Lives in `data/`. Pure conversion only.

```dart
final class PetMapper {
  const PetMapper._();

  static Pet fromDto(PetDto dto) => Pet(
    id: dto.id,
    name: dto.name,
    species: PetSpecies.fromValue(dto.species),
    birthDate: DateTime.parse(dto.birthDate),
    isNeutered: dto.isNeutered,
    breed: dto.breed,
    microchip: dto.microchip,
    photoUrl: dto.photoUrl,
    initialWeight: dto.initialWeight,
  );

  static Map<String, dynamic> toInsertJson(Pet pet) => {
    'name': pet.name,
    'species': pet.species.value,
    'birth_date': pet.birthDate.toIso8601String(),
    'is_neutered': pet.isNeutered,
    'breed': pet.breed,
    'microchip': pet.microchip,
    'photo_url': pet.photoUrl,
    'initial_weight': pet.initialWeight,
  };
}
```

## Enums

Prefer explicit wire values and safe parsing:

```dart
enum PetSpecies {
  dog('dog'),
  cat('cat'),
  other('other');

  const PetSpecies(this.value);
  final String value;

  static PetSpecies fromValue(String value) =>
      PetSpecies.values.firstWhere(
        (e) => e.value == value,
        orElse: () => PetSpecies.other,
      );
}
```

Never serialize with `.toString()`.  
If DTO enum encoding diverges, use `@JsonEnum`/`@JsonValue` at the DTO boundary.

## Failures And Results

Use sealed unions for exhaustive handling:

```dart
@freezed
sealed class PetFailure with _$PetFailure {
  const factory PetFailure.notFound() = _NotFound;
  const factory PetFailure.permissionDenied() = _PermissionDenied;
  const factory PetFailure.unexpected(String message) = _Unexpected;
}

sealed class Result<S, F> {
  const Result();
}
final class Ok<S, F> extends Result<S, F> {
  const Ok(this.value);
  final S value;
}
final class Err<S, F> extends Result<S, F> {
  const Err(this.error);
  final F error;
}
```

Repository contract example:

```dart
abstract interface class PetRepository {
  Future<Result<List<Pet>, PetFailure>> list();
}
```

## Recommended Feature Layout

```text
domain/
  pet.dart
  pet_failure.dart
  pet_repository.dart
  _domain.dart

data/
  pet_dto.dart
  pet_mapper.dart
  pet_datasource.dart
  pet_repository_impl.dart
  _data.dart
```

## Quick Checklist

- [ ] Entity in `domain/`, DTO in `data/`
- [ ] Domain models contain no `fromJson`/`toJson`
- [ ] DTO uses `fieldRename: FieldRename.snake` or explicit `@JsonKey(name: ...)`
- [ ] Mapper owns all DateTime/enum/string-wire conversions
- [ ] Unions/failures use `sealed` for exhaustive `switch`
- [ ] Contracts use `abstract interface class`
- [ ] Build runner regenerated after edits
- [ ] Entities used in skeleton UI expose `mock()` / `mockList()` on the domain class

## Context7 References Used

- Freezed docs (`/rrousselgit/freezed`): immutable classes, custom methods with private constructor, sealed unions.
- json_serializable docs (`/google/json_serializable.dart`): `fieldRename`, `@JsonKey`, enum annotations.
- Dart docs (`/dart-lang/site-www`): class modifiers (`abstract interface`, `sealed`, `final`) and API boundaries.

## I/O Reference

|                |                                                                                                           |
| -------------- | --------------------------------------------------------------------------------------------------------- |
| Trigger        | Creating or refactoring domain entities, DTOs, enums, failures, or repository contracts                   |
| Reads          | `constitution.md` (three-layer architecture, naming conventions), `registry.md` (existing model patterns) |
| Invoked by     | `devflow.plan` (data layer design), `devflow.implement` (model file implementation)                       |
| Related skills | `flutter-riverpod` (providers consuming models), `flutter-supabase` (DTO ↔ Supabase JSON mapping)         |
