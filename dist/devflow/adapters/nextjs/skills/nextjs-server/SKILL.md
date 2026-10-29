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

> **Next.js 16+ default:** `fetch` requests and GET Route Handlers are **uncached by default** (`cache: 'no-store'`). Client navigations also bypass stale cache by default.

Cache strategies:

- **UNCACHED (default in v16+):** standard `fetch()` or DB call with no caching.
- **CACHED (opt-in):** `fetch(url, { next: { revalidate: N } })` for ISR, or `next: { tags: [...] }` + `revalidateTag(tag, 'max')`.
- **`'use cache'` directive (Next.js 16+ stable):** For non-fetch caching (DB queries, ORMs; replaces `unstable_cache`). Configure `cacheLife()` and `cacheTag()`. Constraint: `cookies()`, `headers()`, `searchParams` cannot be read inside `'use cache'` — pass needed values as arguments.

`fetch()` calls with identical URL + options dedupe automatically within a single request lifecycle. Use `React.cache()` to dedupe non-fetch functions (ORM/DB queries) within a request.

Route-level overrides: `export const dynamic`, `revalidate`, `fetchCache` in `page.tsx`.

Full code: cache strategies, `'use cache'` example + migration from `unstable_cache`, preload pattern, route-level config → `references/server-patterns.md`.

## 3) Server Actions

Async functions that run on the server, called from client or server. Add `'use server'` at top of file (preferred) or top of inline async function.

### Server Action rules

- Validate ALWAYS with Zod before any DB/IO operation.
- Return typed discriminated union: `{ success: true, data }` | `{ success: false, error }`.
- Never `throw` toward client — client cannot catch server exceptions.
- Call `revalidatePath()` or `revalidateTag(tag, 'max')` after mutations that affect cached data; `updateTag(tag)` when the user must see their own write immediately.
- Use `redirect()` inside Server Actions for post-mutation navigation (throws internally — put after try/catch).

Full code: file-level and inline Server Action, progressive-enhancement form with `useActionState` → `references/server-patterns.md`.

## 4) API Routes

File: `app/api/[resource]/route.ts`. Named exports map to HTTP methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.

## Reference detail

Detail for API Routes vs Server Actions — decision rule, Async Request APIs (Cookies, Headers, Params), Error Handling, `after()` — post-response code, Runtime Selection, Debug — MCP Endpoint: [references/server-patterns.md](references/server-patterns.md) — load when touching those areas.

## Anti-Patterns

Do NOT:

- Put `process.env` secrets in Client Components or client-importable files — they leak to browser bundle.
- Use `fetch()` in Client Components when data can be fetched server-side and passed as props.
- `throw` from Server Actions toward client — client cannot catch server-side exceptions.
- Skip `revalidatePath()` / `revalidateTag(tag, 'max')` / `updateTag(tag)` after mutations — causes stale UI.
- Wrap `redirect()` or `notFound()` in try/catch — they throw intentionally.
- Use `cache: 'no-store'` on every fetch by default — defeats the performance model.
- Call Server Actions in `useEffect` — use `startTransition` or form `action` instead.
- Put business logic in API Routes when Server Actions would suffice — Server Actions are simpler and type-safe end-to-end.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when `app/api/**`, `**/actions.ts`, `**/action.ts`, or files containing `'use server'` |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md` |
| Related | `nextjs-architecture`, `nextjs-components`, `nextjs-forms` |
