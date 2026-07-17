# Flutter adapter — Setup step

Loaded by `devflow-setup` together with the adapter core (`ADAPTER.md`).

## Setup: templates

`devflow.setup` uses adapter templates first, then global fallback:

- Preferred: `@devflow/adapters/flutter/templates/AGENTS.template.md`
- Preferred: `@devflow/adapters/flutter/templates/REGISTRY.template.md`
- Fallback (if adapter templates are missing): `@devflow/skills/devflow-setup/templates/*.template.md`

Template intent:

- `AGENTS.template.md`: short operational rules + skill references (`@...`) only.
- `REGISTRY.template.md`: compact pattern registry and core conventions.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for `devflow.setup` auto-install.

### flutter-dependencies

- `easy_localization`
- `google_fonts`
- `flutter_riverpod`
- `riverpod_annotation`
- `hooks_riverpod`
- `flutter_hooks`
- `freezed_annotation`
- `json_annotation`

### flutter-dev-dependencies

- `build_runner`
- `riverpod_generator`
- `freezed`
- `json_serializable`
- `custom_lint`
