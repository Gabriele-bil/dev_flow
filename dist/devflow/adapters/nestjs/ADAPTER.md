# NestJS adapter (DevFlow)

Single source of truth for NestJS behavior. Pipeline skills (`devflow-plan`, `devflow-implement`, `devflow-beautify`, `devflow-test`, `devflow-pr`) **must** read `@devflow/config.md`, resolve adapter, then load this core file **plus** the `steps/<step>.md` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **NestJS 10+ · TypeORM · class-validator + class-transformer · Passport-JWT · Jest + Supertest**. Backend/API only — no DOM, no UI framework. Keep output token-lean and imperative.

## Technology skills (load by feature type)

| When | Load |
| ------ | ------ |
| Module structure, folder layout, DI wiring, injection tokens, circular deps, service boundaries | `@devflow/adapters/nestjs/skills/nestjs-architecture/SKILL.md` |
| Exception filters, HTTP exceptions, async error propagation, structured error responses | `@devflow/adapters/nestjs/skills/nestjs-error-handling/SKILL.md` |
| Guards, JWT auth, input validation, output sanitization, rate limiting | `@devflow/adapters/nestjs/skills/nestjs-security/SKILL.md` |
| Caching, lazy-loaded modules, async lifecycle hooks, graceful shutdown, query cost | `@devflow/adapters/nestjs/skills/nestjs-performance/SKILL.md` |
| Entities, repository pattern, transactions, migrations, N+1 avoidance | `@devflow/adapters/nestjs/skills/nestjs-database/SKILL.md` |
| DTOs, serialization, interceptors, pipes, API versioning, OpenAPI/Swagger docs | `@devflow/adapters/nestjs/skills/nestjs-api-design/SKILL.md` |
| Testing module, unit mocks, e2e Supertest flows, mocking external services | `@devflow/adapters/nestjs/skills/nestjs-testing/SKILL.md` |
| Message/event patterns (`@MessagePattern`/`@EventPattern`), queues, health checks | `@devflow/adapters/nestjs/skills/nestjs-microservices/SKILL.md` |

## MCP (when available)

- Required baseline for this adapter:
  - `context7`
  - `sequential-thinking` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
- **Context7**: NestJS, TypeORM, class-validator/class-transformer, Passport docs and version deltas.
- **Sequential Thinking**: break module restructuring, auth flow changes, and multi-step migrations into small, testable steps.

## Caveman response rules (mandatory)

Apply to narrative text in plans, updates, reviews, PR notes:

- Drop: articles, filler (`just/really/basically/actually/simply`), pleasantries, hedging.
- Keep: technical terms exact, code blocks unchanged.
- Prefer: `fix`, `use`, `build`, `test`. Pattern: `[thing] [action] [reason]. [next step].`

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | `steps/setup.md` | Setup templates + dependencies |
| plan | `steps/plan.md` | Plan extra sections and templates |
| implement | `steps/implement.md` | Skill load decision matrix, commands, checklist |
| beautify | `steps/beautify.md` | Beautify commands, review axes, accessibility checks |
| test | `steps/test.md` | Test layout, commands, coverage threshold, verify |
| pr | `steps/pr.md` | PR verification and body checklist |
