# NestJS adapter (DevFlow)

**Verified against:** @nestjs/core@12.3, typeorm@1.1, prisma@7.10, bullmq@6.5, jest@30.5, vitest@5.0, zod@4.6 (2026-10-30)

Single source of truth for NestJS behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **NestJS 12 · Express v5 default · ESM (Vitest) or CommonJS (Jest 30) · ORM per project (TypeORM 1 or Prisma 7) · class-validator DTOs or Standard Schema · `@nestjs/jwt` + Passport · Supertest**. Backend/API only — no DOM, no UI framework. Keep output token-lean and imperative.

## Project choices (resolve once per session)

Read the choice, never assume it. Order: `constitution.md` → `## Key decisions`; else detect from files; else ask user and record answer in `constitution.md` → `## Key decisions`.

| Choice | Detect | Options |
| --- | --- | --- |
| ORM | `prisma/schema.prisma` or `prisma.config.ts` → Prisma; `typeorm` in `package.json` → TypeORM | TypeORM 1 (`@nestjs/typeorm`) or Prisma 7 (`PrismaService`). Never both in one app |
| Validation | `@Body({ schema` in `src/` → Standard Schema; `class-validator` in `package.json` → DTO classes | DTO classes + `ValidationPipe` (default: Swagger CLI plugin, mapped types) or Standard Schema (Zod/Valibot) + `StandardSchemaValidationPipe`. Both pipes may be bound together during a migration |
| Test runner | `vitest` in `package.json` → Vitest; else Jest | ESM projects: Vitest (`nest new` default). CommonJS: Jest 30 |

New code follows the recorded choice. ORM-specific patterns: `nestjs-database` → `references/database-patterns.md` (one table, both ORMs).

## Technology skills (load by feature type)

Triggers live only in `steps/implement.md` → skill load decision matrix. This table says what each skill covers.

| Covers | Skill |
| ------ | ------ |
| Module structure, folder layout, DI wiring, injection tokens, provider scope, config | `@devflow/adapters/nestjs/skills/nestjs-architecture/SKILL.md` |
| Exception filters, HTTP exceptions, async error propagation, logging | `@devflow/adapters/nestjs/skills/nestjs-error-handling/SKILL.md` |
| Guards, JWT auth, input validation, security headers, CSRF, rate limiting, sanitization | `@devflow/adapters/nestjs/skills/nestjs-security/SKILL.md` |
| Caching, lazy-loaded modules, lifecycle hooks, graceful shutdown, query cost | `@devflow/adapters/nestjs/skills/nestjs-performance/SKILL.md` |
| Entities/schema, repositories, transactions, migrations, N+1 — TypeORM or Prisma | `@devflow/adapters/nestjs/skills/nestjs-database/SKILL.md` |
| Response serialization, interceptors, pipes, versioning, OpenAPI | `@devflow/adapters/nestjs/skills/nestjs-api-design/SKILL.md` |
| Testing module, unit mocks, e2e Supertest, mocking external services | `@devflow/adapters/nestjs/skills/nestjs-testing/SKILL.md` |
| `@MessagePattern`/`@EventPattern`, BullMQ queues, Terminus health checks | `@devflow/adapters/nestjs/skills/nestjs-microservices/SKILL.md` |
| Naming, function size, SOLID smells (shared) | `@devflow/adapters/common/skills/common-clean-code/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
- API design & contracts:
  - `openapi` (OpenAPI MCP server) — inspect OpenAPI/Swagger specs, validate DTO boundaries and contract changes
- Conditional (only when used in project):
  - `postgres` (`@microsoft/postgres-mcp` or `mcp-postgres-server`, read-only) — schema introspection, migration drift (add ONLY if project uses PostgreSQL; omit otherwise)
  - `supabase` (Supabase MCP) — schema, RLS, tables (add ONLY if project uses Supabase as backend/DB; omit otherwise)
  - `sentry` (`mcp.sentry.dev` / `getsentry/sentry-mcp`) — error triage and stack traces (add ONLY if project uses Sentry)
- **Context7**: check current NestJS 12, TypeORM 1 / Prisma 7, BullMQ, Terminus docs before writing any API this adapter does not show — these change every minor.
- **Sequential Thinking**: break module restructuring, auth flow changes, and multi-step migrations into small, testable steps.

## Caveman response rules (mandatory)

Narrative text in plans, updates, reviews, PR notes: drop articles, filler, hedging; keep technical terms and code exact. Pattern: `[thing] [action] [reason]. [next step].`

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | `steps/setup.md` | Setup templates + dependencies |
| plan | `steps/plan.md` | Plan extra sections and templates |
| implement | `steps/implement.md` | Skill load decision matrix, commands, checklist |
| beautify | `steps/beautify.md` | Beautify commands, review axes, accessibility checks |
| test | `steps/test.md` | Test layout, commands, coverage threshold, verify |
| pr | `steps/pr.md` | PR verification and body checklist |
