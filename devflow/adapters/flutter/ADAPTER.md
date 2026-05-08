# Flutter adapter (DevFlow)

Single source of truth for Flutter behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then follow sections below.

## Technology skills (load by feature type)

| When | Load |
|------|------|
| Database read/write/auth, schema, RLS | `@devflow/adapters/flutter/skills/flutter-supabase/SKILL.md` |
| Schema migrations / SQL artifacts | `@devflow/adapters/flutter/skills/flutter-supabase-migrations/SKILL.md` |
| New UI screens or visual styling | `@devflow/adapters/flutter/skills/flutter-theme/SKILL.md` |
| Riverpod providers, notifiers, async state | `@devflow/adapters/flutter/skills/flutter-riverpod/SKILL.md` |
| Entities, DTOs, JSON boundaries | `@devflow/adapters/flutter/skills/flutter-models/SKILL.md` |
| Layout, breakpoints, scrollables | `@devflow/adapters/flutter/skills/flutter-layout/SKILL.md` |
| Form / wizard flows | `@devflow/adapters/flutter/skills/flutter-form/SKILL.md` |
| PR review, blast radius, architecture risk checks | `@code-review-graph/skills/code-review-graph/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking)
  - `dart` (required on Flutter projects)
- **Dart MCP** — package APIs, Flutter/Dart signatures (use in plan, implement, beautify).
- **Context7** — third-party docs when Dart MCP is insufficient.
- **Supabase MCP** — schema, RLS, tables when the feature touches the database.

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

## Plan: extra sections and templates

Include these in `plan.md` when applicable (after core sections from `devflow-plan`).

### Dependency ordering (layering)

Order the **File list** bottom-up per project `constitution.md` (typical Petmate-style stack):

1. Database migrations / schema before repositories using new tables  
2. Domain models, failures, repository contracts  
3. Data sources and repository implementations  
4. Riverpod providers and notifiers  
5. UI (pages, widgets, router)  
6. Localization (`assets/i18n/*.json`) and codegen (`dart run slang`, `build_runner`) when new strings or generated files are required  

### Riverpod Providers (table)

```markdown
## Riverpod Providers

| Provider | Type | Responsibility |
|----------|------|----------------|
| `[providerName]` | `[AsyncNotifier / Notifier / Provider / StreamProvider]` | [what it manages] |

[If no new providers: one row stating `None — only existing providers`.]
```

### Widget Tree (indented list; omit if no UI)

For each screen with adaptive layout, branch by breakpoint (compact / medium / expanded). Use `AppBreakpointWidth` on `double` and `AppBreakpointConstraints` on `BoxConstraints` from `lib/core/layout/app_breakpoints.dart` (or paths defined in `constitution.md`).

### Supabase Schema (omit if no DB)

Tables, columns, RLS policies per `flutter-supabase` / `flutter-supabase-migrations`.

### Localization

All user-facing copy via **slang** keys and generated accessors — no hardcoded UI strings.

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
|---|---|
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

### Pre-handoff checklist (implement)

- [ ] `flutter analyze` clean (or remaining issues documented)  
- [ ] No hardcoded user-visible strings in UI  
- [ ] Breakpoints covered for new screens  
- [ ] Loading / error / empty for async UIs where applicable  
- [ ] Repository/domain boundaries match plan; one failure style  

## Beautify: commands

Same as implement: `dart format .`, `flutter analyze`, conditional `build_runner` after edits.

### Beautify: Flutter-specific review axes

Apply these in addition to core `devflow-beautify` axes:

- **Theme-first UI:** no hardcoded colors/text styles when theme tokens exist (`flutter-theme`).
- **Presentation boundaries:** no business/data logic leaking into widgets/screens.
- **Riverpod scope:** avoid broad watches; use `.select()` when only a sub-field is needed (`flutter-riverpod`).
- **Render cost:** avoid expensive work in `build()`; prefer lazy lists (`ListView.builder`/slivers) for large datasets.
- **Responsive layout:** use `LayoutBuilder` + project breakpoints (`AppBreakpointWidth` / `AppBreakpointConstraints`) instead of raw viewport literals.

### Beautify: accessibility checks

Apply these Flutter-specific accessibility checks in addition to core accessibility axis:

- Custom interactive widgets have `Semantics` wrappers with `label`, `button`, `onTap` as appropriate
- Image-only or icon-only buttons include `Semantics(label: ...)` or `tooltip`
- Color contrast: use semantic theme tokens (never hardcode colors that might fail WCAG AA)
- `ExcludeSemantics` used only when intentional (decorative content)
- `FocusNode` management correct for keyboard navigation in custom overlays and dialogs

Severity: **Critical** for screen-reader-blocking issues (missing semantics on primary actions); **Required** for contrast violations; **Nit** for enhancement.

### Beautify: performance profiling trigger

Profile only when plan calls out performance or when a likely hotspot is found:

- Use Flutter DevTools (Performance/CPU/Timeline) before major perf refactors.
- Investigate dropped frames/scroll jank by checking rebuild scope (`Provider`/`Consumer` granularity) before micro-optimizations.
- For large images in lists, follow project decoding/caching patterns.

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: mirror `lib/` under `test/`, suffix `_test.dart`.  
- Integration: `integration_test/features/[feature-name]/[flow]_test.dart`.

### Commands

Unit tests:

```bash
flutter test test/features/[feature-name]/ --reporter expanded
```

Integration (sequential: Android then Chrome):

```bash
flutter test integration_test/features/[feature-name]/ -d emulator-[ID]
```

Use `flutter_test` and Riverpod test utilities; mock Supabase — no real network in unit tests.

### Responsive tests

For UI screens, assert layout variants at compact vs expanded widths using `MediaQuery` overrides per project patterns (`AppBreakpoints`).

## PR: verification

Before push:

```bash
flutter analyze   # expect: No issues found!
flutter test test/ --reporter compact   # expect: All tests passed!
```

### PR body checklist (copy into PR description)

- [ ] All unit tests passing
- [ ] Integration tests passing on Android emulator
- [ ] Integration tests passing on Chrome
- [ ] `flutter analyze` reports no issues
- [ ] `dart format` applied
- [ ] No hardcoded TODO or placeholder comments
- [ ] `registry.md` updated if new patterns were introduced
