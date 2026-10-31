# Flutter adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

Single source of skill triggers. Match each file in the current batch by path or content; load every skill its rows name. `ADAPTER.md` → **Technology skills** is the feature-level index of the same skills.

| File path / content pattern | Load skill |
| --- | --- |
| First file under a new `lib/features/<name>/`; feature file-tree scaffold; code moving between layers | `flutter-architecture` |
| `*/domain/*.dart`, `*_entity.dart`, `*_model.dart`, `*_dto.dart`, `*_mapper.dart`, `*_failure.dart` | `flutter-models` |
| `*/providers/*.dart`, `*_provider.dart`, `*_notifier.dart`; any widget rendering an `AsyncValue` (`.skeleton(`, `ref.watch(`) | `flutter-riverpod` |
| New provider whose scope (widget-local / feature / app-wide) is not fixed by the plan | `common-state-patterns` (`@devflow/adapters/common/skills/common-state-patterns/SKILL.md`) |
| `*_datasource.dart`, `*/datasources/*.dart`, `*_repository_impl.dart`, any file importing `supabase_flutter` | `flutter-supabase` |
| `supabase/migrations/*.sql` | `flutter-supabase-migrations` |
| `*/pages/*.dart`, `*/screens/*.dart`, `*/widgets/*.dart` | `flutter-theme` + `flutter-layout` |
| `lib/core/theme/**` | `flutter-theme` |
| `lib/core/layout/**`, overflow / unbounded-constraint fix | `flutter-layout` |
| `*/forms/*.dart`, `*_form.dart`, any file using `FormBuilder` | `flutter-form` |
| New repository impl, use case or service class; refactor spanning more than one class | `common-clean-code` (`@devflow/adapters/common/skills/common-clean-code/SKILL.md`) |

Load only the skills triggered by the current batch's files. Do not load all skills preemptively.

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

**i18n** (only if `assets/i18n/*.i18n.json` changed): `dart run slang`.

Retry failed steps up to **3** attempts each; then stop and report full output.

### Flutter implementation rules (summary)

- **Responsive UI:** compact / medium / expanded via `LayoutBuilder` + project breakpoint helpers; no magic width literals.  
- **Localization:** slang only for user-visible strings.  
- **UI stack:** follow `flutter-theme`; async UIs render through `.skeleton(mock:)` (`flutter-riverpod`) with error + empty states in slang copy.  
- **State:** prefer hooks + Riverpod per `flutter-riverpod`; contract-first repositories per `flutter-models` / `flutter-supabase`.  
- **Shared components first:** before building a new widget, check `lib/shared/` (or the project-equivalent shared folder) for an existing component that covers the use case. Extend or parameterise a shared widget instead of duplicating it. Create a new shared widget when the same visual pattern appears in more than one feature.

### Barrel files (mandatory)

Every directory with Dart sources has a barrel `_[folder_name].dart` inside it, exporting every public file of that folder (`domain/_domain.dart`, `data/_data.dart`, `providers/_providers.dart`, `widgets/_widgets.dart`, `lib/core/theme/_theme.dart`).

- **Cross-folder import** → nearest barrel of the target folder: `import '../domain/_domain.dart';` — never `../domain/pet.dart`.
- **Same-folder import** → the file directly: `import 'pet_mapper.dart';` — never the folder's own barrel (`_data.dart` from inside `data/`).
- Filter a file out of the barrel only when it is intentionally package-private.

### Pre-handoff checklist (implement)

- [ ] `flutter analyze` clean (or remaining issues documented)  
- [ ] No hardcoded user-visible strings in UI  
- [ ] Breakpoints covered for new screens  
- [ ] Loading / error / empty for async UIs where applicable  
- [ ] Repository/domain boundaries match plan; one failure style  
- [ ] Every new folder has a `_[folder_name].dart` barrel  
- [ ] Cross-folder imports use the barrel; same-folder imports are direct  
- [ ] No widget duplicated across features that already exists (or could live) in `shared/`  
