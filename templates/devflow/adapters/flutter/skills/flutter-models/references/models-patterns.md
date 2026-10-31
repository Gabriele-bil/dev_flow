# Flutter Models — Code Patterns

Rules live in `../SKILL.md`; this file holds one example per decision.

## Entity + `mock()` (domain)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pet.freezed.dart';

@freezed
abstract class Pet with _$Pet {
  const Pet._(); // needed for the getter below

  const factory Pet({
    required String id,
    required String name,
    required PetSpecies species,
    required DateTime birthDate,
    String? breed,
  }) = _Pet;

  factory Pet.mock() => Pet(
    id: 'mock-id',
    name: 'Mock pet name',
    species: PetSpecies.dog,
    birthDate: DateTime(2020, 1, 1),
    breed: 'Mock breed',
  );

  static List<Pet> mockList({int count = 3}) =>
      List.generate(count, (_) => Pet.mock());

  int get ageInYears => DateTime.now().difference(birthDate).inDays ~/ 365;
}
```

## DTO (data)

```dart
part 'pet_dto.freezed.dart';
part 'pet_dto.g.dart';

@freezed
abstract class PetDto with _$PetDto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PetDto({
    required String id,
    required String name,
    required String species,
    required String birthDate,
    String? breed,
  }) = _PetDto;

  factory PetDto.fromJson(Map<String, dynamic> json) => _$PetDtoFromJson(json);
}
```

## Mapper (data)

```dart
final class PetMapper {
  const PetMapper._();

  static Pet fromDto(PetDto dto) => Pet(
    id: dto.id,
    name: dto.name,
    species: PetSpecies.fromValue(dto.species),
    birthDate: DateTime.parse(dto.birthDate),
    breed: dto.breed,
  );

  static Map<String, dynamic> toInsertJson(Pet pet) => {
    'name': pet.name,
    'species': pet.species.value,
    'birth_date': pet.birthDate.toIso8601String(),
    'breed': pet.breed,
  };
}
```

## Enum with wire value

```dart
enum PetSpecies {
  dog('dog'), cat('cat'), other('other');

  const PetSpecies(this.value);
  final String value;

  static PetSpecies fromValue(String v) =>
      values.firstWhere((e) => e.value == v, orElse: () => other);
}
```

## Failure union, `Result`, contract

```dart
@freezed
sealed class PetFailure with _$PetFailure {
  const factory PetFailure.notFound() = PetNotFound;
  const factory PetFailure.permissionDenied() = PetPermissionDenied;
  const factory PetFailure.unexpected(String message) = PetUnexpected;
}

sealed class Result<S, F> { const Result(); }
final class Ok<S, F> extends Result<S, F> { const Ok(this.value); final S value; }
final class Err<S, F> extends Result<S, F> { const Err(this.error); final F error; }

abstract interface class PetRepository {
  Future<Result<List<Pet>, PetFailure>> list();
  Future<Result<Pet, PetFailure>> create(Pet pet);
}

// Consume with switch — exhaustive over the sealed union
String message(PetFailure f) => switch (f) {
  PetNotFound() => t.pets.notFound,
  PetPermissionDenied() => t.common.forbidden,
  PetUnexpected(:final message) => message,
};
```
