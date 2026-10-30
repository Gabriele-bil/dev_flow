---
name: nextjs-server
description: Server Components, Server Actions, Route Handlers, data fetching and Cache Components ('use cache', cacheLife, cacheTag). Load when touching 'use server' files, app/api/**, **/actions.ts, or 'use cache'.
---

# Skill: Next.js Server

## Purpose

Project rules for server code: data fetching, caching under Cache Components, Server Actions, Route Handlers. Detail + one example per decision: `references/server-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Client interactivity, hooks, hydration → `nextjs-components`
- Form UI wiring (RHF, shadcn `Field`) → `nextjs-forms`; route/folder layout → `nextjs-architecture`

## Rules

**Server Components (default).** No directive. `async` + `await` data in body; secrets, DB, Node APIs stay here. Pass serializable props to Client Components.

**Caching — Cache Components on** (`cacheComponents: true`, default in `create-next-app` for Next 16.4). Check current docs with Context7 before writing caching code — API moves each minor.

- Cache = `'use cache'` at top of function/component + `cacheLife('<profile>')` + `cacheTag('<tag>')`. Profiles: `seconds`, `minutes`, `hours`, `days`, `weeks`, `max`, or custom in `next.config.ts`.
- Uncached data (fetch, DB, `cookies()`, `headers()`, `searchParams`) runs per request → wrap reading component in `<Suspense>`; else build error "blocking route".
- `cookies()` / `headers()` / `searchParams` never inside `'use cache'` — read outside, pass value as argument.
- Request-scope dedupe of non-fetch calls: `React.cache()`.
- Route segment config `export const dynamic|revalidate|fetchCache|runtime` → not supported with Cache Components (build error); use `'use cache'` + `cacheLife` instead.
- `unstable_cache` and fetch `next: { revalidate, tags }` → superseded; use `'use cache'` + `cacheLife` + `cacheTag` instead.

**Invalidation after mutation** (pick one per action):

| Need | Call |
| --- | --- |
| User must see own write now (forms, settings) | `updateTag(tag)` — Server Actions only |
| Stale-while-revalidate for other readers | `revalidateTag(tag, 'max')` — two args; one-arg form deprecated |
| Re-render current route, no tagged cache touched | `refresh()` — Server Actions only |
| Whole path | `revalidatePath(path)` |

**Server Actions.**

- File-level `'use server'` in `actions.ts`; inline only for single use inside a Server Component.
- Validate with shared Zod schema (`safeParse`) before any IO. Field errors via `z.flattenError(err).fieldErrors`.
- Return discriminated union `{ success: true, data } | { success: false, error }`; never `throw` toward client.
- Authorize inside every action — actions are public POST endpoints.
- `redirect()` / `notFound()` after try/catch; inside catch call `unstable_rethrow(err)` first.
- Side effects not needed for response (analytics, email) → `after()` from `next/server`.

**Route Handlers** (`app/api/<resource>/route.ts`). Only for external consumers: webhooks, OAuth callbacks, mobile/third-party clients, streaming. Internal mutations → Server Actions (see `steps/plan.md` → Server Actions vs API Routes).

- Invalid body (malformed JSON or schema failure) → `400` with `z.flattenError` payload. One status, everywhere; tests assert `400`.
- Not found → `404`; unexpected → log + `500` generic message.
- `params` is a Promise: `const { id } = await params`.

**Runtime.** Node.js only. No `export const runtime` (Cache Components rejects it; `proxy.ts` always runs on Node).

**Debug.** Dev server exposes `/_next/mcp`; use Next.js DevTools MCP (`get_errors`, `get_routes`, `get_logs`) before guessing.

## Anti-Patterns

- `process.env` secrets in client-importable files — leak to bundle.
- Client-side `fetch` for data a Server Component can load.
- Server Action called from `useEffect` — use form `action` or `startTransition`.
- Mutation without invalidation call → stale UI.
- Business logic in Route Handler when a Server Action fits.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`app/api/**`, `**/actions.ts`, `'use server'`, `'use cache'`) |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md`, `references/server-patterns.md` |
| Writes | Server Components, Server Actions, Route Handlers |
| Related | `nextjs-architecture`, `nextjs-components`, `nextjs-forms` |
