# Flutter + Supabase — Code Patterns

Rules live in `../SKILL.md`; one example per decision. Other query/auth/storage/realtime calls: Supabase MCP / Context7 (`/websites/supabase_reference_dart`).

## Client + repository providers

```dart
// lib/core/env/supabase_client_provider.dart
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

// feature
@riverpod
PetRepository petRepository(Ref ref) =>
    PetRepositoryImpl(PetDatasource(ref.watch(supabaseClientProvider)));
```

## Datasource (raw JSON, throws)

```dart
final class PetDatasource {
  const PetDatasource(this._client);
  final SupabaseClient _client;

  // RLS scopes rows to the signed-in user — no owner filter in the app
  Future<List<Map<String, dynamic>>> list() =>
      _client.from('pets').select().order('created_at', ascending: false);

  Future<Map<String, dynamic>?> byMicrochip(String code) =>
      _client.from('pets').select().eq('microchip', code).maybeSingle();

  Future<Map<String, dynamic>> insert(Map<String, dynamic> row) =>
      _client.from('pets').insert(row).select().single();
}
```

## Repository error mapping

```dart
final class PetRepositoryImpl implements PetRepository {
  const PetRepositoryImpl(this._ds);
  final PetDatasource _ds;

  @override
  Future<Result<List<Pet>, PetFailure>> list() async {
    try {
      final rows = await _ds.list();
      return Ok(rows.map((r) => PetMapper.fromDto(PetDto.fromJson(r))).toList());
    } on PostgrestException catch (e) {
      return Err(_map(e));
    }
  }

  // create(): same try/catch shape around _ds.insert(PetMapper.toInsertJson(pet))

  PetFailure _map(PostgrestException e) => switch (e.code) {
        'PGRST116' => const PetFailure.notFound(),     // no row for .single()
        '42501' => const PetFailure.permissionDenied(), // RLS
        _ => PetFailure.unexpected(e.message),          // add 23505 / 23503 cases when the feature has unique / FK constraints
      };
}
```
