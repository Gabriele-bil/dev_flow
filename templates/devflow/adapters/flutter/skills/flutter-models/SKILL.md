---
name: flutter-models
description: Use when creating or refactoring Flutter domain entities, DTOs, enums, failures, and repository contracts. Applies to Freezed/json_serializable model design, JSON mapping boundaries, and immutable data patterns.
---

# Skill: Flutter Models

Full code examples: `references/models-patterns.md`.

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

Generate code with `dart run build_runner build --delete-conflicting-outputs` (or `watch` during heavy modeling work). Full setup snippet → `references/models-patterns.md`.

## Entity (Domain)

Lives in `domain/`. Represents business meaning only, no JSON methods. Add private constructor (`const Pet._()`) when the entity has custom getters/methods or `mock()`. Full code → `references/models-patterns.md`.

## Skeleton `mock()` (domain)

Lives on the entity in `domain/`. Single source of truth for loading-state data consumed by `AsyncValue.skeleton` / `AsyncSnapshot.skeleton` (`mock:` parameter).

Rules:

- **Name**: `factory Entity.mock()` — never `placeholder()` or widget-local fakes.
- **Shape**: realistic field lengths and non-null values where the loaded UI expects them; skeletonizer masks content, layout must match real data.
- **Lists**: `static List<Entity> mockList({int count = 3})` on the same entity class.
- **Scope**: domain only — no `mock()` on DTOs.

Wiring in UI (see `flutter-riverpod`) and full example → `references/models-patterns.md`.

## DTO (Data Transfer Object)

Lives in `data/`. Maps the transport/storage schema with `@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)`. Use `@JsonKey(...)` when one field needs custom behavior (rename, conversion, required/default). Full code → `references/models-patterns.md`.

## Mapper (Boundary Adapter)

Lives in `data/`. Pure conversion only — `fromDto` builds the domain entity, `toInsertJson` builds the write payload. Full code → `references/models-patterns.md`.

## Enums

Prefer explicit wire values and safe parsing (`fromValue` with `orElse` fallback). Full code → `references/models-patterns.md`.

## Failures And Results

Use sealed unions (`PetFailure`) and a `Result<S, F>` type for exhaustive handling; repository contracts return `Future<Result<List<Pet>, PetFailure>>`. Full code → `references/models-patterns.md`.

## Recommended Feature Layout

`domain/` holds the entity, failure, repository contract; `data/` holds the DTO, mapper, datasource, repository impl. Full tree → `references/models-patterns.md`.

## Quick Checklist

- [ ] Entity in `domain/`, DTO in `data/`
- [ ] Domain models contain no `fromJson`/`toJson`
- [ ] DTO uses `fieldRename: FieldRename.snake` or explicit `@JsonKey(name: ...)`
- [ ] Mapper owns all DateTime/enum/string-wire conversions
- [ ] Unions/failures use `sealed` for exhaustive `switch`
- [ ] Contracts use `abstract interface class`
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
