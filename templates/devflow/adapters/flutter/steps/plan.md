# Flutter adapter — Plan step

Loaded by `devflow-plan` together with the adapter core (`ADAPTER.md`).

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

### Data model (omit if no new persistent entities)

When `devflow-plan` Step 4c generates `data-model.md`: use it as the single source of truth for entity definitions before writing any `*_entity.dart`, `*_dto.dart`, or `*_model.dart` files. Fields in `data-model.md` map to Freezed class properties — do not invent field names or types that diverge from the data model.

### Localization

All user-facing copy via **slang** keys and generated accessors — no hardcoded UI strings.
