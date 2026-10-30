---
name: nestjs-microservices
description: MessagePattern/EventPattern communication, BullMQ background jobs (@nestjs/bullmq, bullmq 6), Terminus health checks. Load when creating or refactoring *.processor.ts, message/event handlers, queue producers, or health controllers.
---

# Skill: NestJS Microservices

## Purpose

Project rules for work that leaves the HTTP request: inter-service messages, background queues, and liveness/readiness checks. Examples: `references/microservices-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix that names `nestjs-microservices`
- In-process domain events between modules — use `nestjs-architecture` (`@nestjs/event-emitter`)
- Shutdown wiring itself — use `nestjs-performance`

## Rules

1. **Message vs event.** `@MessagePattern` only when the caller needs the result (`await firstValueFrom(client.send(...))`); errors → `RpcException`. `@EventPattern` for side effects (`client.emit(...)`, not awaited); return values are discarded, so handlers catch, log and dead-letter their own errors — never rethrow.
2. **Validate payloads** like HTTP input: `@Payload({ schema })` with `StandardSchemaValidationPipe`, or a DTO class with `ValidationPipe`.
3. **Off the request path.** Reports, bulk email, file processing, webhooks' heavy part → BullMQ queue. Producer `@InjectQueue('name')` → `queue.add(name, data, opts)` returns a job id at once; never await the work in the controller.
4. **Consumers = `@nestjs/bullmq`.** `@Processor('name') class X extends WorkerHost` with one `process(job)` branching on `job.name`; worker events via `@OnWorkerEvent('failed')`. `@nestjs/bull` and its `@Process()` decorator are legacy — do not use.
5. **Retries are explicit.** `attempts` + `backoff: { type: 'exponential', delay }` in `defaultJobOptions` or per job; `removeOnComplete`/`removeOnFail` caps; jobs idempotent (retries re-run them).
6. **Repeating jobs = Job Schedulers.** `queue.upsertJobScheduler(id, { pattern | every }, { name, data, opts })` with a stable `id` — safe on every boot. The `repeat` option of `add()` was removed in bullmq 6.
7. **Two health endpoints** (`@nestjs/terminus`). `/health/live`: process-local only (heap), never downstream calls. `/health/ready`: real dependencies, each `.withTimeout(ms)` (the `timeout` option of `pingCheck` is deprecated). Shutdown `503` comes from `gracefulShutdownTimeoutMs` (`nestjs-performance`), not a hand-made flag.
8. **Custom indicators** inject `HealthIndicatorService`: `check(key)` then return `indicator.up(details)` / `indicator.down(details)`, or `.attempt(fn)`. Never throw to signal unhealthy; subclassing `HealthIndicator` and `HealthCheckError` were removed in Terminus 12.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-beautify` per `steps/implement.md` → skill load decision matrix |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nestjs/ADAPTER.md`, `references/microservices-patterns.md` |
| Related | `nestjs-performance` (graceful shutdown), `nestjs-error-handling` (handler errors), `nestjs-architecture` (in-process events) |
