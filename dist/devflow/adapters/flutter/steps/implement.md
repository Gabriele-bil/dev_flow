# Flutter adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
| --- | --- |
| `*/domain/*.dart`, `*_entity.dart`, `*_model.dart` | `flutter-models` |
| `*/providers/*.dart`, `*_provider.dart`, `*_notifier.dart` | `flutter-riverpod` |
| `*/datasource*.dart`, `*_datasource.dart`, `*_repository*.dart` | `flutter-supabase` |
| `supabase/migrations/*.sql`, `*_migration.sql` | `flutter-supabase-migrations` |
| `*/pages/*.dart`, `*/screens/*.dart`, `*/widgets/*.dart` | `flutter-theme` + `flutter-layout` |
| `*/forms/*.dart`, `*_form*.dart`, `*_form_*.dart` | `flutter-form` |

Load only the skills triggered by the current batch's file paths. Do not load all skills preemptively.

## Implement: commands and checklist

### Format, analyze, codegen

Run after substantive edits, in order:

```bash
dart format .
flutter analyze
```

**Codegen** (only if files use `@freezed`, `@riverpod`, `@JsonSerializable`, `@Envied`, or other codegen annotations):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Retry failed steps up to **3** attempts each; then stop and report full output.

### Flutter implementation rules (summary)

- **Responsive UI:** compact / medium / expanded via `LayoutBuilder` + project breakpoint helpers; no magic width literals.  
- **Localization:** slang only for user-visible strings.  
- **UI stack:** follow `flutter-theme`; async UIs need loading / error / empty with slang copy.  
- **State:** prefer hooks + Riverpod per `flutter-riverpod`; contract-first repositories per `flutter-models` / `flutter-supabase`.  
- **Shared components first:** before building a new widget, check `lib/shared/` (or the project-equivalent shared folder) for an existing component that covers the use case. Extend or parameterise a shared widget rather than duplicating it. Create a new shared widget when the same visual pattern appears in more than one feature.

### Barrel files (mandatory)

Every directory containing Dart source files **must** have a barrel file that re-exports all public symbols in that directory.

**Naming convention:** `_[folder_name].dart` — the barrel lives inside the folder it represents.

Examples:

| Folder | Barrel file |
| -------- | ------------- |
| `domain/` | `domain/_domain.dart` |
| `data/` | `data/_data.dart` |
| `providers/` | `providers/_providers.dart` |
| `widgets/` | `widgets/_widgets.dart` |
| `shared/` | `shared/_shared.dart` |
| `lib/core/theme/` | `lib/core/theme/_theme.dart` |

**Import rules:**

1. **Cross-folder imports** — always import from the nearest barrel, never from individual files in another folder:

   ```dart
   // ✅ Good — import the barrel of the target folder
   import '../domain/_domain.dart';

   // ❌ Bad — direct import of a file in another folder
   import '../domain/pet.dart';
   ```

2. **Same-folder imports** — import the file directly (no barrel indirection):

   ```dart
   // ✅ Good — same folder: import the file directly
   import 'pet_mapper.dart';

   // ❌ Bad — do not import the barrel from within the same folder
   import '_data.dart';
   ```

3. **Barrel content** — export every public `.dart` file in the folder; do not filter unless a file is intentionally package-private:

   ```dart
   // data/_data.dart
   export 'pet_dto.dart';
   export 'pet_mapper.dart';
   export 'pet_datasource.dart';
   export 'pet_repository_impl.dart';
   ```

### Pre-handoff checklist (implement)

- [ ] `flutter analyze` clean (or remaining issues documented)  
- [ ] No hardcoded user-visible strings in UI  
- [ ] Breakpoints covered for new screens  
- [ ] Loading / error / empty for async UIs where applicable  
- [ ] Repository/domain boundaries match plan; one failure style  
- [ ] Every new folder has a `_[folder_name].dart` barrel  
- [ ] Cross-folder imports use the barrel; same-folder imports are direct  
- [ ] No widget duplicated across features that already exists (or could live) in `shared/`  
