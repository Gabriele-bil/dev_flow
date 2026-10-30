<!-- devflow-managed:start:patterns -->
| Pattern | When | Path |
| --- | --- | --- |
| Feature Module | Any new domain/feature | `src/<feature>/{<feature>.module.ts,<feature>.controller.ts,<feature>.service.ts,dto/}` (+ `entities/` with TypeORM) |
| Repository | Custom queries beyond basic CRUD (wraps TypeORM `Repository` or `PrismaService`) | `src/<feature>/<feature>.repository.ts` |
| DTO / schema | Every request body / response shape | `src/<feature>/dto/[create\|update\|response]-<feature>.dto.ts` (class) or `.schema.ts` (Standard Schema) |
| Guard | Route-level auth/authorization | `src/common/guards/<name>.guard.ts` |
| Exception Filter | Centralized error shape | `src/common/filters/<name>.filter.ts` |
| Interceptor | Cross-cutting concern (logging, transform, cache) | `src/common/interceptors/<name>.interceptor.ts` |
| Injection Token | Interface-based DI | `src/<feature>/<feature>.tokens.ts` (`export const X_TOKEN = Symbol('X')`) |
| Migration | Schema change | TypeORM `src/database/migrations/<timestamp>-<name>.ts`; Prisma `prisma/migrations/` via `prisma migrate dev` |
| Queue Processor | Background job | `src/<feature>/<feature>.processor.ts` (`@nestjs/bullmq`) |
<!-- devflow-managed:end:patterns -->

<!-- devflow-managed:start:conventions -->
**Naming:** modules/files `kebab-case.type.ts` (`users.service.ts`); classes `PascalCase`; DI tokens `Symbol('Name')` or `SCREAMING_SNAKE_CASE`
**Modules:** one feature module per domain; export only what other modules need; `@Global()` reserved for config/logging/db connection
**DI:** constructor injection only; interfaces injected via token, never a bare interface type
**Validation:** every input validated — DTO + `class-validator` with global `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`, or `@Body({ schema })` with global `StandardSchemaValidationPipe` (choice in `constitution.md`)
**Errors:** throw built-in `HttpException` subclasses; centralize response shape in one global exception filter
**Database:** one ORM, recorded in `constitution.md` (TypeORM 1 or Prisma 7); schema changes through migrations only — never `synchronize: true` or `prisma db push` in a shared environment
**Branches:** `feat/[NNN]_<name>`, `fix/[NNN]_<name>`
**Commits:** `<type>: <desc>` (`feat|fix|chore|docs|perf`)
**Lint:** `npm run lint`
**Test:** `npm test -- --passWithNoTests`
**Build:** `npm run build`
<!-- devflow-managed:end:conventions -->
