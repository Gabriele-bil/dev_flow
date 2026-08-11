---
name: nestjs-database
description: TypeORM entities, migrations, transactions, N+1 avoidance, repository queries. Load when creating or refactoring *.entity.ts, migration files, or any repository/query-builder code.
---

# Skill: NestJS Database

Use when defining entities, writing migrations, wiring transactions, or reviewing query relation-loading for N+1 risk.

Full code examples: `references/database-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (no entity/migration/repository change)
- Pure caching-layer work on top of an already-correct query — use `nestjs-performance`

## Objectives

- Every entity list/detail fetch avoids N+1 — eager `relations`/joins, never a query inside a loop.
- Schema changes only via migrations — `synchronize: true` never used outside local dev.
- Multi-step writes that must succeed/fail together wrapped in a transaction.
- Repository encapsulates query-builder logic (see `nestjs-architecture` §5) — services stay query-free.

## 1) Avoid N+1 Queries (HIGH)

Fetching a list then looping to fetch each item's relation (`for (const order of orders) order.items = await ...`) issues 1+N queries. Fix: `relations: ['items', 'items.product']` on the initial `find()` for a single JOIN query, or `createQueryBuilder` with `leftJoinAndSelect` for more control, or `select` shaping to avoid over-fetching while still joining. For GraphQL resolvers, use `DataLoader` (request-scoped, batches per-tick). Enable `logging: ['query', 'error']` in dev TypeORM config to catch N+1 patterns during development.

## 2) Use Migrations, Never `synchronize: true` (HIGH)

`synchronize: true` outside local dev can silently drop columns/tables/data on deploy — never in any shared environment. All schema changes go through generated migration files (`up`/`down` both implemented — `down` enables rollback). Column renames use the safe four-step pattern: add new column, backfill data, add constraint, drop old column (in a later migration, after verifying the app works) — never a direct rename that risks data loss if the deploy needs to roll back.

## 3) Use Transactions for Multi-Step Operations (HIGH)

Any sequence of writes that must all succeed or all fail together (`create order` + `decrement inventory` + `charge payment`) wraps in `dataSource.transaction(async (manager) => {...})` — every operation inside uses the transactional `manager`, not the injected repository, and a thrown error automatically rolls back everything. For manual control (multi-step validation between operations), use `QueryRunner` directly with explicit `startTransaction()`/`commitTransaction()`/`rollbackTransaction()`/`release()` in a `try/catch/finally`.

## Database Review Checklist

- [ ] No query issued inside a loop over a previously-fetched list — `relations`/joins used instead
- [ ] `synchronize: false` in every non-local environment
- [ ] Every schema change has a migration file with both `up` and `down` implemented
- [ ] Column renames use the additive four-step pattern, not a direct rename
- [ ] Multi-step writes that must be atomic wrapped in `dataSource.transaction()` or `QueryRunner`
- [ ] Query-builder logic lives in a `<feature>.repository.ts`, not inline in the service

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `*.entity.ts`, `**/migrations/*.ts`, `*.repository.ts`, or content uses `createQueryBuilder`/`dataSource.transaction` |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-architecture` (repository pattern placement), `nestjs-performance` (query/index optimization, caching) |
