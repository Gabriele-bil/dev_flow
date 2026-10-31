<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** nestjs
**Adapter:** @devflow/adapters/nestjs/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Feature-module organization — no technical-layer grouping (no bare `controllers/`, `services/` folders).
- Constructor injection only — no `ModuleRef.get()` service-locator pattern.
- ORM, validation style and test runner: as recorded in `constitution.md` → Key decisions. Never mix ORMs.
- All input validated (DTO class + `ValidationPipe`, or `@Body({ schema })` + `StandardSchemaValidationPipe`). No raw `req.body` access.
- All endpoints documented in OpenAPI (`@nestjs/swagger`).
- Run quality commands after edit batches: `npm run lint`, `npm test -- --passWithNoTests`, `npm run build`.
- Required MCP baseline: {{mcp-baseline}}
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
Read a skill only when the work touches its files (full matrix: `@devflow/adapters/nestjs/steps/implement.md`):

- `*.module.ts`, `*.service.ts`, DI tokens, config → `nestjs-architecture`
- `*.controller.ts`, `*.dto.ts`, `*.schema.ts`, pipes, interceptors, Swagger → `nestjs-api-design`
- `*.guard.ts`, `*.strategy.ts`, auth, `main.ts` → `nestjs-security`
- `*.filter.ts`, `@Catch`, `@OnEvent`, `@Cron` → `nestjs-error-handling`
- Cache, lifecycle hooks, shutdown, `main.ts` → `nestjs-performance`
- Entities, repositories, migrations, `prisma/**` → `nestjs-database`
- `*.spec.ts`, `*.e2e-spec.ts` → `nestjs-testing`
- `*.processor.ts`, `*.gateway.ts`, message/event handlers, health checks → `nestjs-microservices`
- Pipeline steps: `/devflow-task`, `/devflow-plan`, `/devflow-implement` — invoked on demand, not imported
<!-- devflow-managed:end:skills -->
