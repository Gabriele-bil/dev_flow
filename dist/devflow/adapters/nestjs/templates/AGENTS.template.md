<!-- devflow-managed:start:stack -->
**Project:** {{project-name}}
**Stack:** nestjs
**Adapter:** @devflow/adapters/nestjs/ADAPTER.md
<!-- devflow-managed:end:stack -->

<!-- devflow-managed:start:rules -->
- Read `constitution.md` and `registry.md` before planning.
- Feature-module organization — no technical-layer grouping (no bare `controllers/`, `services/` folders).
- Constructor injection only — no `ModuleRef.get()` service-locator pattern.
- Load `nestjs-architecture` when work touches modules, services, or DI wiring.
- Load `nestjs-security` when touching guards, auth, or input validation.
- Load `nestjs-database` when touching entities, repositories, or migrations.
- All input validated via DTOs + `class-validator` + global `ValidationPipe`. No raw `req.body` access.
- All endpoints documented with `@nestjs/swagger` decorators.
- Run quality commands after edit batches: `npm run lint`, `npm test -- --passWithNoTests`, `npm run build`.
- Required MCP baseline: `context7`, `sequential-thinking`.
<!-- devflow-managed:end:rules -->

<!-- devflow-managed:start:skills -->
@devflow/skills/devflow-task/SKILL.md
@devflow/skills/devflow-plan/SKILL.md
@devflow/skills/devflow-implement/SKILL.md
@devflow/adapters/nestjs/skills/nestjs-architecture/SKILL.md
@devflow/adapters/nestjs/skills/nestjs-error-handling/SKILL.md
@devflow/adapters/nestjs/skills/nestjs-security/SKILL.md
@devflow/adapters/nestjs/skills/nestjs-database/SKILL.md
@devflow/adapters/nestjs/skills/nestjs-api-design/SKILL.md
@devflow/adapters/nestjs/skills/nestjs-testing/SKILL.md
<!-- devflow-managed:end:skills -->
