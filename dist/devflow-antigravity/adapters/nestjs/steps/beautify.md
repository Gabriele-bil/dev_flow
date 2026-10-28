# NestJS adapter — Beautify step

Loaded by `devflow-beautify` together with the adapter core (`ADAPTER.md`).

## Beautify: commands

Same as implement pipeline: `lint`, `test`, `build`.

```bash
npm run lint
npm run test -- --passWithNoTests
npm run build
```

### Beautify: performance profiling trigger

Profile only when the plan flags performance or a **Critical**-severity hotspot is found:

- New DB-heavy endpoint (joins across >2 tables, N+1-prone loop, unpaginated list) → profile before merge.
- Reported latency regression on an existing endpoint → profile before writing the fix.
- Enable TypeORM query logging (`logging: ['query', 'slow']`, `maxQueryExecutionTime`) to catch N+1 patterns and slow queries directly.
- Use `clinic doctor` / `clinic flame` (Node.js Clinic.js) or `node --prof` for CPU/event-loop profiling under load.
- Load-test the suspect endpoint with `autocannon` or `k6` before/after the fix to confirm the regression is closed.
- Check for missing caching (`CacheModule`, `@nestjs/cache-manager`) on expensive, frequently-read, rarely-changed data.
- Check async lifecycle hooks (`onModuleInit`, `onApplicationBootstrap`) run independent work in parallel (`Promise.all`) instead of unnecessary sequential `await` chains blocking startup.

Default beautify relies on heuristics (indexed columns, explicit `select` column lists over `SELECT *`, eager-loaded relations instead of per-row queries). Profile only when warranted.

### Beautify: NestJS-specific review axes

Apply core `devflow-beautify` axes, then evaluate touched code with relevant NestJS skills:

- `nestjs-architecture` — module boundaries, DI token usage, no circular deps, no god services
- `nestjs-error-handling` — exception filters applied, no swallowed async errors, no unhandled rejections
- `nestjs-security` — guards on protected routes, all input validated, no raw internal errors in responses
- `nestjs-performance` — caching present where warranted, query shape, lifecycle hook correctness
- `nestjs-database` — transactions around multi-step writes, no N+1, migrations used (never `synchronize: true`)
- `nestjs-api-design` — DTOs on every response, versioning respected, pipes over manual parsing
- `nestjs-testing` — coverage, mock quality, no real external calls in unit tests

### Beautify: accessibility checks

NestJS has no DOM/WCAG surface — this section reinterprets accessibility for **API consumers and integrators**: can a client (human developer or downstream service) understand and safely handle what the API returns?

- Structured, consistent error shape across all endpoints — RFC 7807 `application/problem+json` or Nest's default `{statusCode, message, error}`, applied everywhere via one global exception filter, never ad hoc per controller. **Critical.**
- Every `4xx` validation failure names which field(s) failed and why (`class-validator` per-property messages, not a bare "Bad Request"). **Required.**
- HTTP status codes are semantically correct and consistent (`201` create, `204` delete-no-body, `409` conflict, one convention for validation errors — `400` or `422`, not both) — no `200` on error paths, no `500` for expected client errors. **Critical.**
- Every public endpoint carries complete `@nestjs/swagger` decorators (`@ApiOperation`, `@ApiResponse` per status code, `@ApiProperty` on every DTO field) — generated OpenAPI doc has no untyped/`unknown` fields. **Required.**
- Error codes are stable, machine-parseable identifiers alongside human messages (`error.code = "USER_NOT_FOUND"`) when the API has non-English or automated consumers needing i18n-ready errors. **Nit** by default, **Required** if product explicitly needs i18n.
- No leaking of internal details in error responses (stack traces, SQL, file paths, library versions) outside development environment. **Critical.**

Severity: **Critical** = broken or misleading contract for the consumer; **Required** = missing structured info the consumer needs; **Nit** = polish/consistency.
