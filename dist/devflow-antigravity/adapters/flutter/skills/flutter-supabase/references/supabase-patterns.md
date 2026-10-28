# Flutter + Supabase — Code Patterns

## Client access pattern

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

## Datasource boundary rules

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

## Database query patterns

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

## Mutations (write patterns)

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

## Repository error mapping

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

## Auth patterns

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

## Storage patterns

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

## Realtime patterns

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

## RPC and Edge Functions

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
