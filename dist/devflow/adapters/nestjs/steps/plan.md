# NestJS adapter — Plan step

Loaded by `devflow-plan` together with the adapter core (`ADAPTER.md`).

## Plan: extra sections and templates

Include these in `plan.md` when applicable (after core sections from `devflow-plan`).

### Module structure map

Document the feature module tree for touched/new modules:

```text
src/
├── app.module.ts          # root — imports only, no business logic
├── config/                # ConfigModule setup, env schema/validation
├── common/                # shared guards, interceptors, filters, pipes
├── auth/
│   ├── auth.module.ts
│   ├── auth.controller.ts
│   ├── auth.service.ts
│   ├── strategies/
│   └── dto/
└── <feature>/
    ├── <feature>.module.ts
    ├── <feature>.controller.ts
    ├── <feature>.service.ts
    ├── <feature>.repository.ts
    ├── entities/
    └── dto/
```

List module `imports`/`exports` for every new or modified module. Flag any import that would create a circular dependency (Module A imports Module B which imports Module A, directly or transitively) — resolve via shared module extraction or events before implement, not after.

### Endpoint contract table

For each controller endpoint introduced or modified:

| Method | Path | Guard(s) | Request DTO | Response DTO | Status codes |
| --- | --- | --- | --- | --- | --- |
| `POST` | `/users` | `JwtAuthGuard` | `CreateUserDto` | `UserResponseDto` | 201, 400, 401, 409 |
| `GET` | `/users/:id` | `JwtAuthGuard` | — | `UserResponseDto` | 200, 401, 404 |

### Data model (omit if no new persistent entities)

When `devflow-plan` Step 4c generates `data-model.md`: use it as the single source of truth for entity definitions before writing any TypeORM `@Entity()` class, DTO, or migration. Fields in `data-model.md` map to entity columns and DTO properties — do not invent property names or types that diverge from the data model.

### Sync vs async processing decision

Per operation, choose explicitly:

| Operation | Choice | Reason |
| --- | --- | --- |
| Create user record | Sync (HTTP handler) | Caller needs result immediately |
| Send welcome email | Async (queue job, `@nestjs/bullmq`) | Not required for response; retryable |
| Generate report / process large file | Async (queue job) | Long-running; would block request thread |
| Payment webhook receipt | Sync ack + async processing | Provider expects fast `200`; processing deferred |

Rule: caller consumes result synchronously → HTTP handler. Fire-and-forget or long-running → queue job (`nestjs-microservices`).
