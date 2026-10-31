---
name: flutter-supabase-migrations
description: Use when creating, reviewing, or applying Supabase database migrations, especially for remote schema changes, migration drift, RLS updates, and safe production rollout.
---

# Skill: Supabase Migrations (Flutter apps)

## Purpose

Migration files as the single source of schema truth: create, write, push, recover drift, RLS on every table. Supabase-backed apps only.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- App does not use Supabase
- Dart-side queries, datasources, repositories → `flutter-supabase`

## Golden Rules

1. Never edit a migration already applied remotely; every change is a new file.
2. No manual schema edits in Studio for shared/production projects.
3. Push migrations before merging Flutter code that depends on them.
4. RLS enabled + explicit policies on every app table.
5. Additive by default; destructive changes only as a planned, reversible sequence.

## Flow

1. `supabase migration new <snake_case_name>` (project linked once: `supabase link --project-ref <ref>`).
2. Write `supabase/migrations/<timestamp>_<name>.sql` in order: types/extensions → tables/columns/constraints → indexes → triggers/functions → RLS + policies.
3. `supabase migration list` — review pending history.
4. `supabase db push --dry-run`, then `supabase db push`.

**Drift:** `supabase migration list` to see the mismatch → `supabase db pull` (Docker; `auth`/`storage` excluded unless `--schema`). `supabase migration repair <version> --status applied|reverted` only realigns history — never hides failed SQL.

CLI flags change between releases — check Context7 / `supabase <cmd> --help` before using a flag not listed here.

## SQL Conventions

- `public` schema; `snake_case`, plural table names; `id uuid primary key default gen_random_uuid()`.
- `created_at` + `updated_at` `timestamptz not null default now()`; `updated_at` maintained by trigger.
- FKs `<entity>_id references public.<table>(id)` with explicit `on delete`.
- Index every lookup/join column the migration introduces.
- Policies named `<table>_<action>`, tied to ownership/membership:

```sql
alter table public.pets enable row level security;
create policy "pets_select" on public.pets
  for select using ((select auth.uid()) = owner_id);
```

## Destructive Changes

`drop column`, type rewrite, non-null without backfill → split: additive/backfill migration → app rollout → cleanup migration. Keep backward compatibility during rollout; write rollback plan before `db push`.

## After Push

Align Flutter layers bottom-up: entities/DTOs (`flutter-models`) → datasource + repository (`flutter-supabase`) → providers (`flutter-riverpod`) → tests + seed fixtures.

## Checklist

- [ ] Migration created via `supabase migration new`
- [ ] RLS enabled, policies created/updated
- [ ] `supabase migration list` clean; `supabase db push` succeeded
- [ ] Flutter data/domain/state layers match schema

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `supabase/migrations/*.sql` |
| Reads | `supabase/migrations/` (history), `constitution.md` (DB conventions) |
| Invoked by | `devflow.plan` (Supabase Schema section), `devflow.implement` (before datasource code) |
| Related skills | `flutter-supabase` |
