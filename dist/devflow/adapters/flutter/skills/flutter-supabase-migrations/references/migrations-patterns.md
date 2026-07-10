# Supabase Migrations — Command & SQL Reference

## Required CLI Workflow

```bash
supabase login
supabase link --project-ref <project-ref>
```

> `supabase db push` requires a linked project.

## Standard Migration Flow (Remote)

### 1) Create migration

```bash
supabase migration new <snake_case_name>
```

Examples: `create_pets_table`, `add_weight_to_pets`, `create_pet_events_table`.

### 2) Write SQL in `supabase/migrations/<timestamp>_<name>.sql`

Recommended order: types/extensions → tables/columns/constraints → indexes → triggers/functions → RLS + policies.

### 3) Review pending history

```bash
supabase migration list
```

### 4) Push to remote

```bash
supabase db push
```

Optional preflight:

```bash
supabase db push --dry-run
```

## Drift Recovery Workflow

Use when local/remote migration history diverges.

```bash
supabase migration list       # inspect mismatch
supabase db pull              # pull remote schema into a migration file
```

Notes: `db pull` creates a migration file under `supabase/migrations`; requires Docker for schema diffing; `auth`/`storage` schemas excluded by default (use `--schema` if needed).

### Repair migration history (only when necessary)

```bash
supabase migration repair <version> --status applied
supabase migration repair <version> --status reverted
```

Use `repair` only to realign migration history, not to hide failed SQL.

## SQL Conventions

### Table basics

- Use `public` schema unless intentionally different.
- Use `snake_case`; plural table names.
- Use UUID PK by default:

```sql
id uuid primary key default gen_random_uuid()
```

### Timestamps

- Add both:
  - `created_at timestamptz not null default now()`
  - `updated_at timestamptz not null default now()`
- Maintain `updated_at` with trigger/function.

### Foreign keys

- Name columns `<entity>_id`.
- Use `references public.<table>(id)` with explicit delete behavior.

### Indexes

- Add indexes for lookup/join columns introduced by the migration.

## RLS Minimal Pattern

```sql
alter table public.pets enable row level security;

create policy "pets_select" on public.pets
for select using (auth.uid() = owner_id);
```
