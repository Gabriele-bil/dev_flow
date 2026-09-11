---
name: nextjs-server
description: Server Components, Server Actions, API Routes, data fetching with Next.js cache. Load when touching 'use server' files, app/api/**, or **/actions.ts.
---

# Skill: Next.js Server

Use when implementing Server Components with data fetching, Server Actions for mutations, or API Route handlers.

Full code examples: `references/server-patterns.md`.

## Objectives

- Enforce server-first data fetching — fetch as close to data source as possible.
- Enforce typed, non-throwing Server Actions with Zod validation.
- Enforce correct cache strategy per data freshness requirement.
- Keep secrets and sensitive logic server-side only.
- Enforce API Routes only for external-facing endpoints; use Server Actions for internal mutations.

## 1) Server Components (default)

No directive needed — absence of `'use client'` = Server Component.

Capabilities:

- `async/await` directly in component body — no `useEffect` needed for data fetching
- Access to filesystem, database, environment secrets — never exposed to client bundle
- Import server-only libraries (Node.js APIs, ORMs, SDKs with secrets)
- Cannot use React hooks (`useState`, `useEffect`, `useRef`, etc.)
- Cannot attach event handlers directly — pass interactive parts to Client Components

Pattern: Server Component fetches data → passes as props to Client Component (see reference for full example).

## 2) Data Fetching and Cache

> **Next.js 15 default:** `fetch` requests and GET Route Handlers are **uncached by default** (`cache: 'no-store'`). Client navigations also bypass stale cache by default.

Cache strategies:
- **UNCACHED (default in v15):** standard `fetch()` or DB call with no caching.
- **CACHED (opt-in):** `fetch(url, { next: { revalidate: N } })` for ISR, or `next: { tags: [...] }` + `revalidateTag()`.
- **`'use cache'` directive (Next.js 15+):** For non-fetch caching (DB queries, ORMs; replaces `unstable_cache`). Configure `cacheLife()` and `cacheTag()`. Constraint: `cookies()`, `headers()`, `searchParams` cannot be read inside `'use cache'` — pass needed values as arguments.

`fetch()` calls with identical URL + options dedupe automatically within a single request lifecycle. Use `React.cache()` to dedupe non-fetch functions (ORM/DB queries) within a request.

Route-level overrides: `export const dynamic`, `revalidate`, `fetchCache` in `page.tsx`.

Full code: cache strategies, `'use cache'` example + migration from `unstable_cache`, preload pattern, route-level config → `references/server-patterns.md`.

## 3) Server Actions

Async functions that run on the server, called from client or server. Add `'use server'` at top of file (preferred) or top of inline async function.

### Server Action rules

- Validate ALWAYS with Zod before any DB/IO operation.
- Return typed discriminated union: `{ success: true, data }` | `{ success: false, error }`.
- Never `throw` toward client — client cannot catch server exceptions.
- Call `revalidatePath()` or `revalidateTag()` after mutations that affect cached data.
- Use `redirect()` inside Server Actions for post-mutation navigation (throws internally — put after try/catch).

Full code: file-level and inline Server Action, progressive-enhancement form with `useActionState` → `references/server-patterns.md`.

## 4) API Routes

File: `app/api/[resource]/route.ts`. Named exports map to HTTP methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.

### API Routes vs Server Actions — decision rule

| Use API Route when | Use Server Action when |
| --- | --- |
| External consumer (mobile app, third-party) | Mutation from within Next.js app |
| Webhook receiver | Form submission |
| OAuth callback | Button click mutation |
| File upload endpoint | Any user-triggered data change |
| Streaming response (SSE, chunked) | Revalidation after save |

Full code: GET/POST handlers with Zod validation, dynamic route segments (`params` must be awaited: `const { resource } = await params`) → `references/server-patterns.md`.

## 5) Async Request APIs (Cookies, Headers, Params)

> **Next.js 15+ breaking change:** `cookies()`, `headers()`, `params`, and `searchParams` return Promises. You MUST `await` them in Server Components, Route Handlers, and Server Actions.
> - Server Component: `export default async function Page({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ [key: string]: string }> }) { const { id } = await params; ... }`
> - Cookies: `const cookieStore = await cookies(); const token = cookieStore.get('token');`
> - Headers: `const headersList = await headers();`
> Codemod: `npx @next/codemod@latest next-async-request-api .`

`redirect()` and `notFound()` throw internally — place them AFTER try/catch blocks, never inside them.

Full code → `references/server-patterns.md`.

## 6) Error Handling

Server Actions return typed error objects, never throw toward client. Server Components let unexpected errors propagate to `error.tsx`; use `notFound()` for expected not-found cases. API Routes catch and return `NextResponse.json({ error }, { status: 500 })`.

`redirect()`/`notFound()`/`unauthorized()` throw internally — a generic try/catch swallows them. Use `unstable_rethrow(err)` from `next/navigation` to re-throw Next.js internal errors before handling real errors.

Full code → `references/server-patterns.md`.

## 7) `after()` — post-response code

Run secondary work (analytics, logging, cleanup) after the response finishes streaming, without blocking response time. Guaranteed to complete even if client disconnects. Full code → `references/server-patterns.md`.

## 8) Runtime Selection

Default runtime = **Node.js**. Do not change unless necessary (`export const runtime = 'edge'`).

| Use Node.js (default) when | Use Edge when |
| --- | --- |
| DB access (Prisma, Drizzle, pg) | Middleware (globally distributed) |
| File system access | Request geolocation / A-B testing |
| Node.js-only packages | Ultra-low latency, no Node.js APIs needed |
| Auth, cron, heavy computation | Simple request rewriting |

Edge runtime limitations: no Node.js APIs, no native addons, no filesystem, smaller bundle budget.

## Anti-Patterns

Do NOT:

- Put `process.env` secrets in Client Components or client-importable files — they leak to browser bundle.
- Use `fetch()` in Client Components when data can be fetched server-side and passed as props.
- `throw` from Server Actions toward client — client cannot catch server-side exceptions.
- Skip `revalidatePath()` / `revalidateTag()` after mutations — causes stale UI.
- Wrap `redirect()` or `notFound()` in try/catch — they throw intentionally.
- Use `cache: 'no-store'` on every fetch by default — defeats the performance model.
- Call Server Actions in `useEffect` — use `startTransition` or form `action` instead.
- Put business logic in API Routes when Server Actions would suffice — Server Actions are simpler and type-safe end-to-end.

## Debug — MCP Endpoint

Next.js exposes `/_next/mcp` in development for AI-assisted debugging (Next.js 16+ enabled by default; < 16 needs `experimental.mcpServer: true`). Tools: `get_errors`, `get_routes`, `get_project_metadata`, `get_logs`, `get_server_action_by_id`. Full curl example and tool table → `references/server-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when `app/api/**`, `**/actions.ts`, `**/action.ts`, or files containing `'use server'` |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md` |
| Related | `nextjs-architecture`, `nextjs-components`, `nextjs-forms` |
