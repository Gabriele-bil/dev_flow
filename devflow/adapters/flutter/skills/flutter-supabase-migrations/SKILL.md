---
name: flutter-supabase-migrations
description: Use when creating, reviewing, or applying Supabase database migrations, especially for remote schema changes, migration drift, RLS updates, and safe production rollout.
---

# Supabase Migrations for Flutter

## Overview

Use migration files as single source of truth for schema changes.
Do not edit remote schema manually in Studio for production workflows.

## When to Use

- Adding/changing tables, columns, constraints, indexes, enums, or RLS policies.
- Syncing local and remote schema history.
- Fixing migration drift between local and remote.
- Deploying DB changes before updating Flutter data layer.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Required CLI Workflow

```bash
supabase login
supabase link --project-ref <project-ref>
```

> `supabase db push` requires a linked project.

## Golden Rules

1. Never edit old migration files after they are applied remotely.
2. Every schema change gets a new migration file.
3. Apply migrations before shipping Flutter code that depends on them.
4. RLS must be explicitly enabled and policy-backed on app tables.
5. Prefer additive migrations; avoid destructive operations unless planned and reversible.

## Standard Migration Flow (Remote)

### 1) Create migration

```bash
supabase migration new <snake_case_name>
```

Examples:

- `create_pets_table`
- `add_weight_to_pets`
- `create_pet_events_table`

### 2) Write SQL in `supabase/migrations/<timestamp>_<name>.sql`

Recommended order:

1. types/extensions (if needed)
2. tables/columns/constraints
3. indexes
4. triggers/functions
5. RLS + policies

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

### Inspect mismatch

```bash
supabase migration list
```

### Pull remote schema into a migration file

```bash
supabase db pull
```

Notes:

- `db pull` creates a migration file under `supabase/migrations`.
- It requires Docker for schema diffing.
- `auth` and `storage` schemas are excluded by default (use `--schema` if needed).

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

## RLS Conventions

1. Enable RLS on every app table.
2. Create explicit policies for the operations your app needs.
3. Keep policy names predictable (`<table>_<action>`).
4. Keep policy logic tied to ownership/membership rules.

Minimal pattern:

```sql
alter table public.pets enable row level security;

create policy "pets_select" on public.pets
for select using (auth.uid() = owner_id);
```

## Destructive Change Policy

For risky operations (`drop column`, type rewrite, non-null without backfill):

- Split into multiple migrations:
  1. additive/backfill-safe phase
  2. app rollout
  3. cleanup phase
- Ensure backward compatibility during rollout window.
- Define rollback plan before `db push`.

## Flutter Integration Order

After successful `supabase db push`:

1. Update entities/models and serializers.
2. Update datasource queries and DTO mapping.
3. Update repositories/use cases.
4. Update Riverpod notifiers/providers.
5. Update tests and seed fixtures.

Do not merge app-layer changes that depend on columns/tables not yet pushed remotely.

## Common Mistakes

- Writing SQL directly in remote Studio and skipping migration files.
- Editing an old migration that is already applied.
- Forgetting `supabase link` before `db push`.
- Shipping schema changes without RLS/policies.
- Using `migration repair` as a shortcut for broken migrations.

## Pre-Ship Checklist

- [ ] New migration created via `supabase migration new`.
- [ ] SQL reviewed for idempotency/safety assumptions.
- [ ] RLS enabled and policies created/updated.
- [ ] `supabase migration list` checked.
- [ ] `supabase db push` completed successfully.
- [ ] Flutter data/domain/state layers aligned with schema.
- [ ] Migration drift checked and resolved (if any).

## I/O Reference

|                |                                                                                                |
| -------------- | ---------------------------------------------------------------------------------------------- |
| Trigger        | Any feature that creates or modifies Supabase tables, columns, RLS policies, or functions      |
| Reads          | `supabase/migrations/` (existing migration history), `constitution.md` (DB conventions)        |
| Invoked by     | `devflow.plan` (Supabase Schema section), `devflow.implement` (before writing datasource code) |
| Related skills | `flutter-supabase` (Flutter-side datasource and repository patterns)                           |
