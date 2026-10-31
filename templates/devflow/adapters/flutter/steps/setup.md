# Flutter adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- Preferred: `@devflow/adapters/flutter/templates/AGENTS.template.md`
- Preferred: `@devflow/adapters/flutter/templates/REGISTRY.template.md`
- Fallback (if adapter templates are missing): `@devflow/skills/devflow-setup/templates/*.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + "when you touch X → read skill Y" list. No `@` skill imports — they load into every session.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

### flutter-dependencies

- `slang`
- `slang_flutter`
- `google_fonts`
- `flutter_riverpod`
- `riverpod_annotation`
- `hooks_riverpod`
- `flutter_hooks`
- `freezed_annotation`
- `json_annotation`
- `flutter_form_builder`
- `form_builder_validators`
- `skeletonizer`
- `supabase_flutter` — only when the project uses Supabase (manifest or setup answer); skip otherwise

### flutter-dev-dependencies

- `build_runner`
- `riverpod_generator`
- `freezed`
- `json_serializable`

### Post-install config

- `riverpod_lint` is an `analysis_server_plugin`, not a dev dependency (`custom_lint` removed from setup — do not use). Add to `analysis_options.yaml` next to `pubspec.yaml`:

  ```yaml
  plugins:
    riverpod_lint: ^<latest from pub.dev>
  ```

- slang: `slang.yaml` with `input_directory: assets/i18n`; files `assets/i18n/<locale>.i18n.json`; generate with `dart run slang`.
- `.skeleton(mock:)` extension: create `lib/core/async/async_value_skeleton.dart` from `flutter-riverpod` → `references/riverpod-patterns.md` if missing.
