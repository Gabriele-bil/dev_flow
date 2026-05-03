---
name: flutter-supabase
description: Use when implementing or refactoring Flutter data/auth/storage/realtime code with Supabase. Covers provider-based client access, datasource boundaries, Postgrest query patterns, storage paths, realtime streams, RPC/functions, and repository error mapping.
---

# Skill: Flutter + Supabase

Use for data-layer work on `supabase_flutter` in Flutter + Riverpod architecture.

## Objectives

- Keep Supabase usage centralized and testable
- Enforce datasource/repository separation
- Use current Supabase APIs safely (`single`, `maybeSingle`, `stream(primaryKey:)`, `uploadBinary`, `rpc`, `functions.invoke`)
- Standardize auth, storage, realtime, and error handling

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## 1) Client access pattern (mandatory)

Always access the client via provider injection.

```dart
// core/env/supabase_client_provider.dart
@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) =>
    Supabase.instance.client;
```

```dart
// feature provider
@riverpod
PetRepository petRepository(PetRepositoryRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return PetRepositoryImpl(PetDatasource(client));
}
```

Never call `Supabase.instance.client` directly inside repositories, use cases, or UI widgets.

## 2) Datasource boundary rules

- One datasource class per feature aggregate
- Datasource returns raw JSON only:
  - `Map<String, dynamic>`
  - `List<Map<String, dynamic>>`
- Datasource throws; it does not map errors
- No domain mapping and no business logic in datasource

```dart
class PetDatasource {
  final SupabaseClient _client;
  const PetDatasource(this._client);
}
```

## 3) Database query patterns

### Read lists

```dart
Future<List<Map<String, dynamic>>> fetchAll(String ownerId) =>
    _client
        .from('pets')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
```

### Read exactly one row

Use `.single()` when the row must exist and be unique.

```dart
Future<Map<String, dynamic>> fetchById(String id) =>
    _client.from('pets').select().eq('id', id).single();
```

### Read optional single row

Use `.maybeSingle()` when "not found" is valid.

```dart
Future<Map<String, dynamic>?> fetchByMicrochip(String code) =>
    _client.from('pets').select().eq('microchip_code', code).maybeSingle();
```

### Pagination

Use `.range(start, end)` with stable ordering.

```dart
Future<List<Map<String, dynamic>>> fetchPage({
  required String petId,
  required int page,
  required int pageSize,
}) =>
    _client
        .from('log_entries')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
```

### Join style

```dart
Future<List<Map<String, dynamic>>> fetchWithMembers(String ownerId) =>
    _client
        .from('pets')
        .select('*, pet_members(user_id, joined_at)')
        .eq('owner_id', ownerId);
```

## 4) Mutations (write patterns)

After `insert`/`update`/`upsert`, chain `.select()` (and usually `.single()`) when the caller needs returned rows.

```dart
Future<Map<String, dynamic>> insert(Map<String, dynamic> row) =>
    _client.from('pets').insert(row).select().single();
```

```dart
Future<Map<String, dynamic>> update(String id, Map<String, dynamic> patch) =>
    _client.from('pets').update(patch).eq('id', id).select().single();
```

```dart
Future<Map<String, dynamic>> upsert(Map<String, dynamic> row) =>
    _client.from('pets').upsert(row).select().single();
```

```dart
Future<void> deleteById(String id) =>
    _client.from('pets').delete().eq('id', id);
```

Use `onConflict` for natural-key upserts when needed:

```dart
await _client.from('pets').upsert(row, onConflict: 'owner_id,microchip_code');
```

## 5) Repository error mapping (mandatory)

Repositories convert datasource exceptions into typed failures.

```dart
PetFailure mapPostgrest(PostgrestException e) => switch (e.code) {
  'PGRST116' => const PetFailure.notFound(),
  '23505' => const PetFailure.alreadyExists(),
  '23503' => const PetFailure.invalidReference(),
  '42501' => const PetFailure.permissionDenied(),
  _ => PetFailure.unexpected(e.message),
};
```

## 6) Auth patterns

```dart
final user = _client.auth.currentUser;
final session = _client.auth.currentSession;
```

```dart
await _client.auth.signInWithPassword(email: email, password: password);
await _client.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: kIsWeb ? null : 'io.supabase.flutter://callback',
);
await _client.auth.signOut();
```

Expose auth events via provider:

```dart
@riverpod
Stream<AuthState> authState(AuthStateRef ref) =>
    ref.watch(supabaseClientProvider).auth.onAuthStateChange;
```

## 7) Storage patterns

```dart
Future<String> uploadFile({
  required String bucket,
  required String path,
  required Uint8List bytes,
  required String contentType,
}) async {
  await _client.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );
  return _client.storage.from(bucket).getPublicUrl(path);
}
```

```dart
Future<void> deleteFile(String bucket, String path) =>
    _client.storage.from(bucket).remove([path]);
```

Storage path convention:

```text
[bucket]/[user_id]/[pet_id]/[filename]
pet-photos/abc123/xyz789/profile.jpg
pet-documents/abc123/xyz789/vaccine_card.pdf
```

## 8) Realtime patterns

Use realtime only for collaborative or multi-device live views.

```dart
@riverpod
Stream<List<LogEntry>> logEntries(LogEntriesRef ref, String petId) =>
    ref
        .watch(supabaseClientProvider)
        .from('log_entries')
        .stream(primaryKey: ['id'])
        .eq('pet_id', petId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(LogEntryMapper.fromJson).toList());
```

Prefer `AsyncNotifier` + manual refresh for non-live screens.

## 9) RPC and Edge Functions

Use RPC for database-side logic:

```dart
final result = await _client.rpc(
  'search_cities',
  params: {'search_term': 'San', 'country_id': 1},
);
```

Use Edge Functions for server code that needs secrets or external integrations:

```dart
final res = await _client.functions.invoke(
  'process-order',
  body: {'order_id': '12345'},
);
```

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
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Trigger        | Any feature involving Supabase data read/write, auth, storage, realtime, or RPC calls                                                            |
| Reads          | `constitution.md` (data layer conventions), `registry.md` (existing datasource/repository patterns)                                              |
| Invoked by     | `devflow.plan` (when feature involves DB), `devflow.implement` (datasource and repository files)                                                 |
| Related skills | `flutter-riverpod` (notifiers calling repositories), `flutter-models` (DTOs and domain entities), `flutter-supabase-migrations` (schema changes) |
