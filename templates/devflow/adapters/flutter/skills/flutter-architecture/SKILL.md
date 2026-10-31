---
name: flutter-architecture
description: Use when designing a new Flutter feature, reviewing cross-layer dependencies, deciding which layer owns a piece of logic, or scaffolding a feature's file tree against the DevFlow Riverpod stack.
---

# Skill: Flutter Architecture

## Purpose

Layer ownership + dependency direction for Flutter features. `devflow-plan` uses it for file tree + ordering; `devflow-implement` before scaffolding a new feature folder.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Cosmetic UI change with no state or data → `flutter-theme` / `flutter-layout`
- Style review of existing code → `devflow-beautify`

## Input Contract

- [ ] `task.md` exists and is approved
- [ ] `constitution.md` read — stack and feature-folder naming confirmed

## Layers

Dependency direction: **UI → Providers → Domain ← Data**

| Layer | Folder | Owns |
| ------- | -------- | ------ |
| Domain | `lib/features/<name>/domain/` | Entities (+ `mock()`), sealed failures, repository contracts |
| Data | `lib/features/<name>/data/` | DTOs, mappers, datasources, repository impls |
| Providers | `lib/features/<name>/providers/` | `@riverpod` notifiers; call repository contracts |
| UI | `lib/features/<name>/pages/` + `widgets/` | Screens and widgets; watch providers only |

Shared: `lib/core/` — theme, routing, layout helpers, `async/async_value_skeleton.dart`, shared widgets.

Dependency rules:

- Domain: no imports from data, providers, or UI.
- Providers: depend on domain contracts, not data implementations.
- UI: watches providers only; no direct repository or datasource calls.
- Cross-folder imports via nearest barrel (`_domain.dart`, `_data.dart`, …); same-folder imports direct (`steps/implement.md` → Barrel files).

## Feature File Tree

Single page: `pages/<name>_page.dart` flat in the feature. Multiple pages: each page gets `pages/<page>/` with its own `providers/`, `widgets/`, `<page>_page.dart`, `_<page>.dart` barrel; feature-level `providers/` + `widgets/` hold only what pages share; `pages/_pages.dart` re-exports page barrels. Full trees: [`references/feature-tree.md`](references/feature-tree.md).

## Workflow

Bottom-up, same order as `steps/plan.md` → Dependency ordering:

1. **Domain** — entity + `mock()`, sealed failure, repository contract → `flutter-models`
2. **Data** — DTO, mapper, datasource, repository impl → `flutter-models` + `flutter-supabase` (Supabase apps)
3. **Providers** — `@riverpod` notifier on repository contract → `flutter-riverpod`
4. **UI** — pages + widgets; async UI via `.skeleton(mock:)` → `flutter-riverpod`, `flutter-theme`, `flutter-layout`
5. **Barrels** — `_[folder].dart` in every new folder
6. **Localization** — slang keys for every user-visible string; `dart run slang`
7. **Codegen** — `dart run build_runner build --delete-conflicting-outputs` after `@freezed` / `@riverpod`

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Entity holds `fromJson` | JSON = data layer; domain stays pure |
| Skip layers for simple CRUD | All layers mandatory; thin = fast, not skippable |
| `ChangeNotifier` ViewModel | Riverpod notifiers only |
| Skip barrel for small folder | Barrel mandatory regardless of size |
| Business logic in widget | Logic in notifier/repository — widget stays testable |
| Use-case class for simple logic | Use cases only for cross-repository work |

## I/O Reference

| | |
| - | - |
| Trigger | `steps/implement.md` matrix row: new `lib/features/<name>/`, file-tree scaffold, cross-layer move |
| Reads | `constitution.md` (stack + naming), `plan.md` (file list section) |
| Writes | Informs file list + dependency ordering in `plan.md` |
| Invoked by | `devflow.plan` (architecture + file list), `devflow.implement` (pre-scaffold) |
| Related | `flutter-models`, `flutter-riverpod`, `flutter-supabase`, `flutter-theme`, `flutter-layout`, `common-clean-code` |
