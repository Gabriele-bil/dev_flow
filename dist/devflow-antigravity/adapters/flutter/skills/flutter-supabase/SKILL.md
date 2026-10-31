---
name: flutter-supabase
description: Supabase rules for Flutter — provider-based client access, datasource boundaries, Postgrest queries, storage paths, realtime streams, RPC/functions, repository error mapping. Use when writing Flutter data/auth/storage/realtime code backed by Supabase.
---

# Skill: Flutter + Supabase

## Purpose

Data layer on `supabase_flutter`: client via provider, raw-JSON datasources, repositories mapping `PostgrestException` to typed failures. Supabase-backed apps only.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- App does not depend on `supabase_flutter`
- Schema, RLS or SQL changes → `flutter-supabase-migrations`
- DTO/entity shape → `flutter-models`

## Rules

1. **Client:** only through `supabaseClientProvider` (`@Riverpod(keepAlive: true)`). `Supabase.instance.client` appears once — in that provider; never in repositories, use cases or widgets.
2. **Datasource:** one per feature aggregate; returns raw JSON (`Map<String, dynamic>` / `List<Map<String, dynamic>>`); throws, never catches; no mapping or business logic.
3. **Repository impl:** calls datasource, maps JSON → DTO → entity (`flutter-models` mapper), catches `PostgrestException` / `StorageException` / `AuthException` and returns typed failures. One `mapPostgrest` per feature.
4. **Cardinality:** `.single()` when the row must exist; `.maybeSingle()` when absence is valid. Pagination: `.range(from, to)` with stable `.order(...)`.
5. **Mutations:** chain `.select()` (+ `.single()`) when caller needs the written row; natural-key upsert via `onConflict:`.
6. **Auth:** session state exposed by one `authStateProvider` (stream of `auth.onAuthStateChange`); widgets never call `auth` directly.
7. **Storage:** path `<user_id>/<entity_id>/<filename>` inside the bucket; upload via `uploadBinary`; private buckets → signed URLs, not `getPublicUrl`.
8. **Realtime:** `.stream(primaryKey: [...])` only for collaborative / multi-device live views; other screens use `AsyncNotifier` + invalidate/refresh.
9. **Server logic:** DB-side → `rpc(...)`; secrets or third-party calls → Edge Functions (`functions.invoke`). No service-role key in the app.

Provider, datasource and error-mapping code: [`references/supabase-patterns.md`](references/supabase-patterns.md). Query builder, auth, storage and realtime signatures → Supabase MCP / Context7 (`/websites/supabase_reference_dart`) before writing them.

## Anti-Patterns

| Avoid | Use instead |
| --- | --- |
| `Supabase.instance.client` outside the client provider | `ref.watch(supabaseClientProvider)` |
| try/catch in datasource | Throw in datasource, map in repository |
| Datasource returns entities | Raw JSON from datasource |
| `.single()` on optional row | `.maybeSingle()` |
| Realtime on every list | Realtime only where live sync matters |

## Checklist

- [ ] Client only from provider
- [ ] Datasource: no business logic, no error mapping
- [ ] Repository maps every Supabase exception to a typed failure
- [ ] Storage paths namespaced by `user_id`
- [ ] Realtime only on live screens

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `*_datasource.dart`, `*/datasources/*.dart`, `*_repository_impl.dart`, files importing `supabase_flutter` |
| Reads | `constitution.md` (data layer conventions), `registry.md` (datasource/repository patterns) |
| Invoked by | `devflow.plan` (feature touches DB), `devflow.implement` (datasource + repository files) |
| Related skills | `flutter-riverpod`, `flutter-models`, `flutter-supabase-migrations` |
