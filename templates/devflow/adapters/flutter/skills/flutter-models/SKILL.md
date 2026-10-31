---
name: flutter-models
description: Use when creating or refactoring Flutter domain entities, DTOs, enums, failures, and repository contracts. Applies to Freezed/json_serializable model design, JSON mapping boundaries, and immutable data patterns.
---

# Skill: Flutter Models

## Purpose

Immutable domain entities, DTOs, mappers, failures and repository contracts with freezed 4 + json_serializable; entity `mock()` for skeleton loading UI.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Provider/notifier state shape → `flutter-riverpod`
- Supabase query or error-code mapping → `flutter-supabase`
- Form field values before submit → `flutter-form`

## Rules

- **Class modifiers** (freezed ≥3 fails codegen without them):
  - `@freezed abstract class X with _$X` — one factory (entities, DTOs).
  - `@freezed sealed class X with _$X` — several factories (failures, unions); consume with `switch` patterns — freezed no longer generates `.when`/`.map` by default, do not use them.
  - `abstract interface class XRepository` — repository contracts.
  - `final class` — concrete impls not meant for subtyping.
- No `final` on factory parameters — removed in freezed 4 (Dart 3.13 disallows it).
- **Boundaries:** domain holds no JSON/Supabase code; DTO + mapper in `data/` own wire format, DateTime/enum parsing, snake_case.
- **DTO JSON config:** `@JsonSerializable(fieldRename: FieldRename.snake)` on the **factory constructor**, not the class; `@JsonKey` on constructor parameters.
- **Mapper:** `final class` with static `fromDto` / `toInsertJson`; pure conversion, no I/O.
- **Enums:** explicit wire value + `fromValue` with `orElse` fallback.
- **Failures + results:** sealed failure union per feature; contracts return `Future<Result<T, XFailure>>` (project `Result` sealed type). One failure style per feature.
- Private constructor `const X._();` only when entity has getters/methods.
- Codegen: `dart run build_runner build --delete-conflicting-outputs`.

## Skeleton `mock()` (domain)

Single source of loading-state data for `.skeleton(mock:)` (`flutter-riverpod`).

- `factory X.mock()` on the entity — never `placeholder()`, never widget-local fakes, never on DTOs.
- `static List<X> mockList({int count = 3})` when a list provider renders it.
- Realistic field lengths, non-null where loaded UI expects values — skeletonizer paints real layout.
- Only on entities actually rendered through `.skeleton`.

Code (entity + mock, DTO, mapper, failure, `Result`): [`references/models-patterns.md`](references/models-patterns.md). freezed / json_serializable signatures change between majors — check Context7 (`/rrousselgit/freezed`) before writing an unfamiliar annotation option.

## Checklist

- [ ] Entity in `domain/`, DTO + mapper in `data/`
- [ ] No `fromJson`/`toJson` on domain entities
- [ ] `abstract` / `sealed` keyword on every `@freezed` class
- [ ] DTO `@JsonSerializable` on factory constructor
- [ ] Unions consumed with `switch`, not `.when`/`.map`
- [ ] Skeleton-rendered entities expose `mock()` / `mockList()`

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `*/domain/*.dart`, `*_entity.dart`, `*_model.dart`, `*_dto.dart`, `*_mapper.dart`, `*_failure.dart` |
| Reads | `constitution.md` (layers, naming), `registry.md` (model patterns), `data-model.md` when present |
| Invoked by | `devflow.plan` (data layer design), `devflow.implement` (model files) |
| Related skills | `flutter-riverpod` (`.skeleton` consumer), `flutter-supabase` (DTO ↔ Supabase JSON) |
