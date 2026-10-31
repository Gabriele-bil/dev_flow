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
- Turn on the project ORM's query logging with a slow-query threshold (check option names with Context7 for TypeORM 1 / Prisma 7) to catch N+1 and slow queries.
- `clinic doctor` / `clinic flame` or `node --prof` for CPU/event-loop profiling; `autocannon` or `k6` before/after the fix to confirm the regression closed.

Default beautify relies on heuristics from `nestjs-performance` and `nestjs-database`. Profile only when warranted.

### Beautify: NestJS-specific review axes

Apply core `devflow-beautify` axes, then the rules of each skill the touched files trigger in `steps/implement.md` → skill load decision matrix (`nestjs-architecture`, `nestjs-error-handling`, `nestjs-security`, `nestjs-performance`, `nestjs-database`, `nestjs-api-design`, `nestjs-testing`, `nestjs-microservices`, `common-clean-code`). Each skill's `## Rules` is the review list — do not restate it here.

### Beautify: accessibility checks

NestJS has no DOM/WCAG surface — this section reinterprets accessibility for **API consumers and integrators**: can a client (human developer or downstream service) understand and safely handle what the API returns?

- Structured, consistent error shape across all endpoints — RFC 7807 `application/problem+json` or Nest's default `{statusCode, message, error}`, applied everywhere via one global exception filter, never ad hoc per controller. **Critical.**
- Every `4xx` validation failure names which field(s) failed and why (per-property messages from `ValidationPipe` or `StandardSchemaValidationPipe`, not a bare "Bad Request"). **Required.**
- HTTP status codes are semantically correct and consistent (`201` create, `204` delete-no-body, `409` conflict, one convention for validation errors — `400` or `422`, not both) — no `200` on error paths, no `500` for expected client errors. **Critical.**
- Every public endpoint carries `@ApiOperation` and `@ApiResponse` per status code; request/response fields typed through the Swagger CLI plugin / `@ApiProperty` (DTO classes) or derived from `@Body({ schema })` (Standard Schema) — generated OpenAPI doc has no untyped/`unknown` fields. **Required.**
- Error codes are stable, machine-parseable identifiers alongside human messages (`error.code = "USER_NOT_FOUND"`) when the API has non-English or automated consumers needing i18n-ready errors. **Nit** by default, **Required** if product explicitly needs i18n.
- No leaking of internal details in error responses (stack traces, SQL, file paths, library versions) outside development environment. **Critical.**

Severity: **Critical** = broken or misleading contract for the consumer; **Required** = missing structured info the consumer needs; **Nit** = polish/consistency.
