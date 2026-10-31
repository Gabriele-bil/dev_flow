# NestJS adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

Only place where adapter skill triggers live. Match each file in the current batch (path first, then content); load every skill its rows name. A file matching no row loads no adapter skill.

| File path / content pattern | Load skill |
| --- | --- |
| `*.module.ts`, `*.tokens.ts`, `config/**`, files with `@Inject(`, `registerAs(`, `Scope.REQUEST` | `nestjs-architecture` |
| `*.service.ts` | `nestjs-architecture`, `common-clean-code` |
| `*.controller.ts` | `nestjs-api-design`, `nestjs-security` |
| `*.dto.ts`, `*.schema.ts`, `*.pipe.ts`, `*.interceptor.ts`, files with `@nestjs/swagger` | `nestjs-api-design` |
| `*.filter.ts`, files with `@Catch(`, `HttpException` subclasses, `@OnEvent(`, `@Cron(` | `nestjs-error-handling` |
| `*.guard.ts`, `*.strategy.ts`, `auth/**`, files importing `@nestjs/jwt`, `@nestjs/passport`, `@nestjs/throttler` | `nestjs-security` |
| `main.ts` | `nestjs-security`, `nestjs-performance` |
| Files with `CacheModule`, `CACHE_MANAGER`, `LazyModuleLoader`, `onModuleInit`, `onApplicationBootstrap`, `onApplicationShutdown` | `nestjs-performance` |
| `*.entity.ts`, `*.repository.ts`, `migrations/**`, `prisma/**`, `prisma.config.ts`, `*prisma.service.ts`, files with `DataSource`, `$transaction` | `nestjs-database` |
| `*.spec.ts`, `*.e2e-spec.ts`, `test/**` | `nestjs-testing` |
| `*.gateway.ts`, `*.processor.ts`, `health/**`, files with `@MessagePattern`, `@EventPattern`, `@nestjs/bullmq`, `@nestjs/terminus` | `nestjs-microservices` |

Common skill paths: `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/<name>/SKILL.md`. Adapter skill paths: `ADAPTER.md` → Technology skills. Load only skills triggered by the current batch.

## Implement: commands and checklist

### Format, lint, test, build

Run after substantive edits, in order:

```bash
npm run lint
npm run test -- --passWithNoTests
npm run build
```

Retry failed steps up to **3** attempts each; then stop and report full output.

### Codegen (Nest CLI schematics)

New resource, module, controller, or service → prefer `nest g` over hand-written boilerplate:

```bash
nest g resource <name>       # module + controller + service + CRUD + DTOs + spec
nest g module <name>
nest g service <name>
nest g controller <name>
```

Review generated code against `nestjs-architecture` — schematics do not enforce export discipline, DI tokens, or the project's validation choice.

### Pre-handoff checklist (implement)

- [ ] `lint`, `test`, `build` pass (or failures documented)
- [ ] Every touched file matched against the decision matrix; listed skills applied
- [ ] New modules follow feature organization (no bare `controllers/`, `services/` dirs)
- [ ] Constructor injection only — no `ModuleRef.get()` service locator
- [ ] New input validated per `ADAPTER.md` → Project choices (DTO class or `@Body({ schema })`), never manual parsing
- [ ] Data access uses the project ORM only (`ADAPTER.md` → Project choices)
