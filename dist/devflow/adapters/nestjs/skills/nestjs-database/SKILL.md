---
name: nestjs-database
description: Data access with the project ORM (TypeORM 1 or Prisma 7) — schema/entities, repositories, transactions, migrations, N+1 avoidance. Load when creating or refactoring *.entity.ts, prisma/schema.prisma, migration files, or repository/query code.
---

# Skill: NestJS Database

## Purpose

Project rules for persistence that hold for both supported ORMs; the ORM-specific form of each rule is one row in `references/database-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-database`
- Caching on top of a correct query — use `nestjs-performance`
- Response shape of returned records — use `nestjs-api-design`

## Rules

0. **Resolve the ORM first** (`ADAPTER.md` → Project choices). Use only its column in the reference table. Never add the other ORM, never hand-roll SQL where the ORM has an API.
1. **Repositories own queries.** `<feature>.repository.ts` wraps TypeORM `Repository<T>` or `PrismaService`; services hold no query builders and no ORM types in their public API.
2. **No N+1.** Never query inside a loop over fetched rows. Load relations in the first query (TypeORM `relations` / join; Prisma `include` / `select`), or batch with `IN`. GraphQL field resolvers → request-scoped `DataLoader`.
3. **Fetch only what is used.** Explicit `select` on list endpoints; paginate every list (`skip`/`take`); index every column used in frequent `WHERE`/`JOIN`/`ORDER BY` (declared in the entity or `schema.prisma`, shipped by migration).
4. **Migrations only.** Every schema change is a generated, reviewed migration committed with the code. Never `synchronize: true` (TypeORM) or `prisma db push` (Prisma) outside a throwaway local DB. Deploy runs `migration:run` / `prisma migrate deploy`.
5. **Expand–contract for destructive changes.** Rename/drop: add new column → backfill → switch code → drop old in a later release. Never a one-step rename on a live table.
6. **Atomic multi-write.** Writes that must succeed together run in one transaction callback; every call inside uses the transactional handle (TypeORM `manager`, Prisma `tx`), never the injected repository. No external I/O (HTTP, queue, email) inside the transaction — publish after commit (outbox if it must not be lost).
7. **TypeORM 1 specifics.** Find options are object-shaped (`relations: { posts: true }`, `select: { id: true }`); `null`/`undefined` in `where` throws — use `IsNull()`; non-nullable relations now `INNER JOIN` (orphans drop out). Removed in v1, never generate: `findByIds`, `@EntityRepository`, `getRepository()`/`getConnection()` globals.
8. **Prisma 7 specifics.** Generator `prisma-client` with `output`; import `PrismaClient` from that generated path; a driver adapter (`@prisma/adapter-pg`, …) is required; connection URL lives in `prisma.config.ts`, not `schema.prisma`. `$use` middleware removed → `$extends`.
9. **Versions move fast.** Before writing an ORM API not shown in the reference, check current docs with Context7 (TypeORM 1.x / Prisma 7.x).

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md`, `references/database-patterns.md`, `constitution.md` (Key decisions) |
| Related | `nestjs-architecture` (repository placement), `nestjs-performance` (caching, indexes under load), `nestjs-testing` (repository mocks) |
