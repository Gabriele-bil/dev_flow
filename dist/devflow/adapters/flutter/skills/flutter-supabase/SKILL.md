---
name: flutter-supabase
description: Use for Flutter data/auth/storage/realtime code with Supabase — provider-based client access, datasource boundaries, Postgrest queries, storage paths, realtime streams, RPC/functions, repository error mapping.
---

# Skill: Flutter + Supabase

Use for data-layer work on `supabase_flutter` in Flutter + Riverpod architecture.

Full code examples: `references/supabase-patterns.md`.

## Objectives

- Keep Supabase usage centralized and testable
- Enforce datasource/repository separation
- Use current Supabase APIs safely (`single`, `maybeSingle`, `stream(primaryKey:)`, `uploadBinary`, `rpc`, `functions.invoke`)
- Standardize auth, storage, realtime, and error handling

## 1) Client access pattern (mandatory)

Always access the client via provider injection (`supabaseClientProvider`). Never call `Supabase.instance.client` directly inside repositories, use cases, or UI widgets. Full code → `references/supabase-patterns.md`.

## 2) Datasource boundary rules

- One datasource class per feature aggregate
- Datasource returns raw JSON only (`Map<String, dynamic>` / `List<Map<String, dynamic>>`)
- Datasource throws; it does not map errors
- No domain mapping and no business logic in datasource

## 3) Database query patterns

Use `.single()` when the row must exist and be unique, `.maybeSingle()` when "not found" is valid, `.range(start, end)` with stable ordering for pagination, and `.select('*, related(...)')` for joins. Full read patterns → `references/supabase-patterns.md`.

## 4) Mutations (write patterns)

After `insert`/`update`/`upsert`, chain `.select()` (and usually `.single()`) when the caller needs returned rows. Use `onConflict` for natural-key upserts. Full code → `references/supabase-patterns.md`.

## 5) Repository error mapping (mandatory)

Repositories convert datasource exceptions into typed failures by switching on `PostgrestException.code` (e.g. `PGRST116` → not found, `23505` → already exists, `42501` → permission denied). Full code → `references/supabase-patterns.md`.

## 6) Auth patterns

Use `_client.auth.currentUser` / `currentSession`, `signInWithPassword`, `signInWithOAuth`, `signOut`. Expose auth events via a provider wrapping `auth.onAuthStateChange`. Full code → `references/supabase-patterns.md`.

## 7) Storage patterns

Upload with `storage.from(bucket).uploadBinary(...)`, delete with `.remove([path])`. Path convention: `[bucket]/[user_id]/[pet_id]/[filename]`. Full code → `references/supabase-patterns.md`.

## 8) Realtime patterns

Use realtime only for collaborative or multi-device live views, via `.stream(primaryKey: [...])`. Prefer `AsyncNotifier` + manual refresh for non-live screens. Full code → `references/supabase-patterns.md`.

## 9) RPC and Edge Functions

Use RPC (`_client.rpc(...)`) for database-side logic. Use Edge Functions (`_client.functions.invoke(...)`) for server code that needs secrets or external integrations. Full code → `references/supabase-patterns.md`.

## 10) Anti-patterns

| Avoid                                                  | Use instead                                        |
| ------------------------------------------------------ | -------------------------------------------------- |
| `Supabase.instance.client` scattered in app            | `supabaseClientProvider`                           |
| Catching in datasource                                 | Throw in datasource, map in repository             |
| Domain entities returned by datasource                 | Raw JSON from datasource                           |
| `.single()` when row is optional                       | `.maybeSingle()`                                   |
| Realtime for every list                                | Realtime only where live sync matters              |
| Missing `.select()` after mutations when row is needed | Chain `.select()` (+ `.single()` when appropriate) |

## Quick checklist before merging

- Client only retrieved from provider
- Datasource has no business logic and no error mapping
- Repository maps `PostgrestException` to typed failures
- Read paths use correct cardinality (`single` vs `maybeSingle`)
- Realtime only on screens that truly need live updates
- Storage paths include `user_id` namespace

## I/O Reference

|                |                                                                                                                                                  |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trigger        | Any feature involving Supabase data read/write, auth, storage, realtime, or RPC calls                                                            |
| Reads          | `constitution.md` (data layer conventions), `registry.md` (existing datasource/repository patterns)                                              |
| Invoked by     | `devflow.plan` (when feature involves DB), `devflow.implement` (datasource and repository files)                                                 |
| Related skills | `flutter-riverpod` (notifiers calling repositories), `flutter-models` (DTOs and domain entities), `flutter-supabase-migrations` (schema changes) |
