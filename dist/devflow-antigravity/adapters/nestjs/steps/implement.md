# NestJS adapter — Implement step

Loaded by `devflow-implement` together with the adapter core (`ADAPTER.md`).

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
| --- | --- |
| `*.module.ts` | `nestjs-architecture` |
| `*.service.ts`, files with constructor DI, `@Inject()`, or injection tokens | `nestjs-architecture` |
| `*.controller.ts` | `nestjs-api-design` |
| `*.dto.ts`, `*.pipe.ts`, `*.interceptor.ts` | `nestjs-api-design` |
| `*.filter.ts`, files with `@Catch()` or custom `HttpException` subclasses | `nestjs-error-handling` |
| `*.guard.ts`, files importing `@nestjs/jwt`, `@nestjs/passport`, `@nestjs/throttler`, `class-validator` | `nestjs-security` |
| Files with `CacheModule`, `@Cacheable`-style wrappers, `onModuleInit`, `onApplicationBootstrap`, `enableShutdownHooks` | `nestjs-performance` |
| `*.entity.ts`, `*.repository.ts`, `migrations/**` | `nestjs-database` |
| `*.spec.ts`, `*.e2e-spec.ts` | `nestjs-testing` |
| `*.gateway.ts`, `*.processor.ts`, files with `@MessagePattern`, `@EventPattern`, `@nestjs/bullmq` | `nestjs-microservices` |

Load only skills triggered by current batch's file paths. Do not load all skills preemptively.

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

Review generated code against `nestjs-architecture` before commit — schematics do not enforce feature-module export discipline or DI token conventions.

### Pre-handoff checklist (implement)

- [ ] `lint`, `test`, `build` pass (or failures documented)
- [ ] Relevant NestJS skills loaded and applied for touched areas
- [ ] New modules follow feature organization (no technical-layer grouping: no bare `controllers/`, `services/` dirs)
- [ ] Constructor injection only — no `ModuleRef.get()` service-locator pattern
- [ ] New DTOs carry `class-validator` decorators; controllers rely on global `ValidationPipe`, not manual parsing
