---
name: nestjs-microservices
description: MessagePattern/EventPattern communication, BullMQ background jobs, Terminus health checks. Load when creating or refactoring *.processor.ts, message/event handlers, or health controllers.
---

# Skill: NestJS Microservices

Use when wiring inter-service messaging (`@MessagePattern`/`@EventPattern`), background job queues (`@nestjs/bullmq`), or liveness/readiness health checks (`@nestjs/terminus`).

Full code examples: `references/microservices-patterns.md`.

## When NOT to Use

- File does not match trigger pattern in `ADAPTER.md` (no message/event/queue/health-check code)
- Single-service monolith with no queue/microservice surface — skip this skill entirely

## Objectives

- `@MessagePattern` only when the caller genuinely needs a response; `@EventPattern` for fire-and-forget — never block a request on a notification side effect.
- Long-running/expensive work (report generation, bulk email, file processing) moved off the HTTP request path into a BullMQ queue.
- Every microservice/deployable exposes `/health/live` and `/health/ready` via `@nestjs/terminus`, checked against real dependencies (DB, cache, downstream services).

## 1) Message and Event Patterns (MEDIUM)

`@MessagePattern` = request-response: caller `await`s (`firstValueFrom(client.send(...))`), used when the result must gate further logic (e.g. inventory check before confirming an order). `@EventPattern` = fire-and-forget: caller `emit()`s and moves on, used for notifications/analytics/side effects that must never block or fail the primary operation. Never `@MessagePattern` a handler the caller doesn't wait on (couples the sender to the handler's latency/failures for no reason) and never `@EventPattern` a handler whose return value the caller actually needs (`@EventPattern` return values are silently ignored). Errors: `@MessagePattern` handlers throw `RpcException` to propagate to the caller; `@EventPattern` handlers must handle their own errors locally (log + dead-letter, never rethrow — nothing is listening for it).

## 2) Message Queues for Background Jobs (MEDIUM-HIGH)

`@nestjs/bullmq` for anything that shouldn't block an HTTP response: report generation, bulk email, file processing, scheduled maintenance. Producer (`@InjectQueue('name') queue: Queue`) calls `.add()` and returns immediately with a job ID/handle — never `await` the actual work inline in the controller. Consumer is a `@Processor('name')` class with `@Process('jobName')` methods; report progress via `job.updateProgress()` for client polling. Configure `attempts` + `backoff: { type: 'exponential' }` per queue/job so transient failures retry automatically instead of silently dropping work. Repeating jobs (`repeat: { cron: ... }`) need a stable `jobId` to prevent duplicate registration on restart.

## 3) Health Checks (MEDIUM-HIGH)

`@nestjs/terminus`, split into two distinct endpoints — conflating them causes bad orchestrator behavior:

- **Liveness** (`/health/live`) — "is the process alive/should Kubernetes restart it": cheap, local checks only (memory heap), no calls to a downstream DB/API. Reflects the process, not its dependencies.
- **Readiness** (`/health/ready`) — "can this instance accept traffic right now": checks real dependencies (`TypeOrmHealthIndicator.pingCheck`, Redis ping, critical downstream API), each with a short timeout so a slow dependency doesn't itself become a health-check timeout. Return `503` immediately once graceful shutdown starts (pairs with `nestjs-performance` §5) so the orchestrator stops routing new traffic before the process exits.

Custom `HealthIndicator` subclasses for business-specific health (queue backlog, circuit-breaker state) — `throw new HealthCheckError(...)` on failure, otherwise return `this.getStatus(key, true, {...details})`.

## Microservices Review Checklist

- [ ] `@MessagePattern` used only where the caller awaits/needs the response
- [ ] `@EventPattern` handlers never return a value the caller depends on
- [ ] `@EventPattern` handlers catch their own errors — never rethrow
- [ ] No long-running work (report/bulk-email/file-processing) executed inline in an HTTP handler — moved to a BullMQ queue
- [ ] Queue jobs configured with `attempts`/`backoff`; repeating jobs have a stable `jobId`
- [ ] `/health/live` checks only the process itself; `/health/ready` checks real dependencies with timeouts
- [ ] Readiness returns `503` during graceful shutdown

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `*.processor.ts`, or content has `@MessagePattern`/`@EventPattern`/`@InjectQueue`/`HealthCheckService` |
| Reads | `@devflow/adapters/nestjs/ADAPTER.md` |
| Related | `nestjs-performance` (graceful shutdown pairs with readiness state), `nestjs-architecture` (event-driven decoupling via `EventEmitter2`, the in-process analog) |
