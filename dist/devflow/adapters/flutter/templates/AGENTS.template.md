<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** flutter
**Adapter:** @devflow/adapters/flutter/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Respect order: migrations -> domain -> data -> Riverpod -> UI -> i18n/codegen.
- Use `slang` keys for user-visible copy; no hardcoded UI strings.
- Cover compact/medium/expanded layouts with project breakpoints.
- Run `dart format .` then `flutter analyze` after edit batches.
- Required MCP baseline: {{mcp-baseline}}
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
Pipeline steps (`/devflow:task`, `/devflow:plan`, …) load their own skills. Never `@`-import skills here — they would load in every session.

When you touch → read skill (full matrix: adapter `steps/implement.md`):

- new `lib/features/<name>/` → `flutter-architecture`
- `domain/`, `*_dto.dart`, `*_mapper.dart` → `flutter-models`
- `providers/`, `*_notifier.dart`, `AsyncValue` in UI → `flutter-riverpod`
- `pages/`, `screens/`, `widgets/` → `flutter-theme` + `flutter-layout`
- forms (`FormBuilder`) → `flutter-form`
- Supabase datasource / repository impl → `flutter-supabase`; `supabase/migrations/*.sql` → `flutter-supabase-migrations`
- PR review / blast radius → `code-review-graph`
<!-- devflow-managed:end:skills -->
