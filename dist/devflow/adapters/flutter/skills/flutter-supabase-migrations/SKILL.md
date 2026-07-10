---
name: flutter-supabase-migrations
description: Use when creating, reviewing, or applying Supabase database migrations, especially for remote schema changes, migration drift, RLS updates, and safe production rollout.
---

# Supabase Migrations for Flutter

## Overview

Use migration files as single source of truth for schema changes.
Do not edit remote schema manually in Studio for production workflows.

Full commands and SQL: `references/migrations-patterns.md`.

## When to Use

- Adding/changing tables, columns, constraints, indexes, enums, or RLS policies.
- Syncing local and remote schema history.
- Fixing migration drift between local and remote.
- Deploying DB changes before updating Flutter data layer.

## Golden Rules

1. Never edit old migration files after they are applied remotely.
2. Every schema change gets a new migration file.
3. Apply migrations before shipping Flutter code that depends on them.
4. RLS must be explicitly enabled and policy-backed on app tables.
5. Prefer additive migrations; avoid destructive operations unless planned and reversible.

## Standard Migration Flow (Remote)

1. `supabase migration new <snake_case_name>` — new migration file.
2. Write SQL in `supabase/migrations/<timestamp>_<name>.sql`; order: types/extensions → tables/columns/constraints → indexes → triggers/functions → RLS + policies.
3. `supabase migration list` — review pending history.
4. `supabase db push` (optionally `--dry-run` first) — push to remote (requires `supabase link`).

## Drift Recovery Workflow

Use when local/remote migration history diverges: `supabase migration list` to inspect mismatch, `supabase db pull` to pull remote schema into a migration file (requires Docker; `auth`/`storage` schemas excluded by default).

`supabase migration repair <version> --status applied|reverted` only to realign migration history, not to hide failed SQL.

## SQL Conventions

- `public` schema unless intentionally different; `snake_case`, plural table names; UUID PK by default.
- Timestamps: both `created_at` and `updated_at` (`timestamptz not null default now()`), `updated_at` maintained via trigger/function.
- Foreign keys: `<entity>_id` columns, `references public.<table>(id)` with explicit delete behavior.
- Indexes: add for lookup/join columns introduced by the migration.

## RLS Conventions

1. Enable RLS on every app table.
2. Create explicit policies for the operations your app needs.
3. Keep policy names predictable (`<table>_<action>`).
4. Keep policy logic tied to ownership/membership rules.

## Destructive Change Policy

For risky operations (`drop column`, type rewrite, non-null without backfill): split into multiple migrations (additive/backfill-safe phase → app rollout → cleanup phase), ensure backward compatibility during rollout window, define rollback plan before `db push`.

## Flutter Integration Order

After successful `supabase db push`: 1) entities/models and serializers, 2) datasource queries and DTO mapping, 3) repositories/use cases, 4) Riverpod notifiers/providers, 5) tests and seed fixtures.

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
