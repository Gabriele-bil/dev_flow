---
name: nextjs-architecture
description: App Router folders, route segments, layout nesting, server/client boundary, proxy.ts. Load when creating routes, layouts, or reorganizing feature folders.
---

# Skill: Next.js Architecture

## Purpose

Project App Router structure: route groups, colocation, boundary placement, dependency flow, `proxy.ts`. Tree, providers and proxy examples: `references/architecture-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Data fetching, caching, Server Actions inside a route → `nextjs-server`
- Interactive component internals → `nextjs-components`

## Baseline

- Next.js 16 App Router only — no Pages Router, no `next/router`.
- TypeScript `"strict": true`.
- Server Component default; `'use client'` only per rules below.

## Structure rules

- Route groups split layouts: `(marketing)/` public, `(app)/` authenticated (auth check in `(app)/layout.tsx` and again in each Server Action).
- Colocation: route-only code in private folders inside route (`_components/`, `_lib/`), Server Actions in route `actions.ts`.
- Shared code at root: `components/ui/` (shadcn), `components/<feature>/`, `lib/<domain>/`. No `src/` dir.
- `proxy.ts` at project root (sibling of `app/`), export `proxy()`. Runs on Node only. Keep it to redirects/rewrites/header checks — no DB calls, no auth decisions that skip per-action checks.
- Root `layout.tsx`: `html`, `body`, fonts, `<Providers>` only. No per-page data.
- `loading.tsx` for routes with async data; `error.tsx` (`'use client'`) for routes that can fail; `global-error.tsx` includes `<html><body>`.
- Parallel slot `@name/` needs `default.tsx` returning `null`; intercepted modal closes with `router.back()`.

## Server/Client boundary

Promote to Client Component only when file needs state/effect hooks, DOM event handlers, browser APIs, or a library that does.

- `'use client'` as deep as possible — never on root `layout.tsx` or whole `page.tsx`.
- Context providers in one `providers.tsx` (`'use client'`), imported by root layout.
- Server data passed down as props — no client re-fetch.

## Dependency flow

```text
page.tsx → _components/*.tsx → actions.ts / lib/<domain>/*.ts → DB / external API
```

- Pages orchestrate, components render, actions mutate, `lib/` fetches.
- No component calls external API directly; no raw `fetch` in `page.tsx` — delegate to `lib/`.

## Naming

Folders/files `kebab-case`; components `PascalCase` function names; Server Actions file `actions.ts`; private folders `_`; route groups `()`.

## Review checklist

- [ ] `(app)` / `(marketing)` groups separate auth and public layouts
- [ ] Route-only code colocated in `_components/` / `_lib/`
- [ ] Root layout free of business logic
- [ ] `loading.tsx` / `error.tsx` where async or failing
- [ ] `'use client'` only where required, deepest level
- [ ] Dependency flow respected

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`app/**` segment files, `proxy.ts`) |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md`, `references/architecture-patterns.md` |
| Writes | Route segments, layouts, `proxy.ts`, folder layout |
| Related | `nextjs-server`, `nextjs-components` |
