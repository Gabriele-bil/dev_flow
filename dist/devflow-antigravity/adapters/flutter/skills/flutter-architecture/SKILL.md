---
name: flutter-architecture
description: Use when designing a new Flutter feature, reviewing cross-layer dependencies, deciding which layer owns a piece of logic, or scaffolding a feature's file tree against the DevFlow Riverpod stack.
---

## Purpose

Define layer ownership and dependency direction for new features; used in `devflow-plan` to produce correct file trees and in `devflow-implement` before scaffolding.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md`
- Feature is purely cosmetic UI with no state or data (use `flutter-theme` / `flutter-layout`)
- Reviewing existing code style (use `devflow-beautify`)

## Input Contract

- [ ] `task.md` exists and is approved
- [ ] `constitution.md` read — stack and feature-folder naming confirmed

## Layers

Dependency direction: **UI → Providers → Domain ← Data**

| Layer | Folder | Owns |
| ------- | -------- | ------ |
| Domain | `lib/features/<name>/domain/` | Entities, sealed failures, repository contracts |
| Data | `lib/features/<name>/data/` | DTOs, mappers, datasources, repository impls |
| Providers | `lib/features/<name>/providers/` | `@riverpod` notifiers; calls repository contracts |
| UI | `lib/features/<name>/pages/` + `widgets/` | Screens and widgets; watches providers only |

Shared: `lib/core/` — theme, routing, layout helpers, shared widgets.

Dependency rules:

- Domain: no imports from data, providers, or UI.
- Providers: depend on domain contracts, not data implementations.
- UI: watches providers only; no direct repository or datasource calls.
- Cross-folder imports use nearest barrel (`_domain.dart`, `_data.dart`, …). Same-folder: direct import.

## Feature File Tree

Full tree for single-page and multi-page features: see [`references/feature-tree.md`](references/feature-tree.md).

Summary:

- **Single page** — `pages/<name>_page.dart` flat inside the feature.
- **Multiple pages** — each page becomes `pages/<page>/` subfolder with its own `providers/`, `widgets/`, `<page>_page.dart`, and `_<page>.dart` barrel.
- Feature-level `providers/` and `widgets/` hold elements shared across pages; page-level subfolders hold page-scoped elements only.
- `pages/_pages.dart` re-exports all page barrels.

## Workflow

Implement bottom-up (per `ADAPTER.md` dependency ordering):

1. **Domain** — entity, sealed failure, repository contract → `flutter-models`
2. **Data** — DTO, mapper, datasource, repository impl → `flutter-supabase`
3. **Providers** — `@riverpod` notifier consuming repository contract → `flutter-riverpod`
4. **UI** — pages + widgets; `.skeleton(mock:)` for async UIs → `flutter-theme` + `flutter-layout`
5. **Barrels** — `_[folder].dart` in every new folder; cross-folder imports via barrel
6. **Localization** — slang keys for all user-visible strings; no hardcoded copy
7. **Codegen** — `dart run build_runner build --delete-conflicting-outputs` after `@freezed` / `@riverpod` annotations

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Entity holds `fromJson` | JSON = data layer; domain stays pure |
| Skip layers for simple CRUD | All layers mandatory; thin = fast, not skippable |
| `ChangeNotifier` ViewModel | DevFlow uses Riverpod notifiers only |
| Skip barrel for small folder | Barrel mandatory regardless of size |
| Business logic in widget | Logic in UI breaks testability + layer contract |
| Use Case class for simple logic | Use cases only for complex cross-repository work |

## I/O Reference

| | |
| - | - |
| Trigger | New feature architecture, layer ownership decisions, feature file-tree scaffold |
| Reads | `constitution.md` (stack + naming), `plan.md` (file list section) |
| Writes | Informs file list + dependency ordering in `plan.md` |
| Invoked by | `devflow.plan` (architecture + file list), `devflow.implement` (pre-scaffold) |
| Related | `flutter-models` (domain/data), `flutter-riverpod` (providers), `flutter-supabase` (datasources), `flutter-theme`, `flutter-layout` |
