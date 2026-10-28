---
name: nextjs-architecture
description: App Router folders, route segments, layout nesting, server/client boundary. Load when creating routes, layouts, or reorganizing feature folders.
---

# Skill: Next.js Architecture

Use when creating new routes, layouts, reorganizing feature folders, or reviewing architectural consistency.

Full code examples: `references/architecture-patterns.md`.

## Objectives

- Keep App Router structure deterministic and reviewable.
- Enforce route group separation (auth vs no-auth layout).
- Enforce colocation: route-specific code lives inside its route folder.
- Keep server/client boundary as deep in the tree as possible.
- Enforce one-way dependency flow: page → components → actions/services → external.

## 1) Baseline (mandatory)

- Next.js 16+ App Router. No Pages Router.
- TypeScript strict mode (`"strict": true` in `tsconfig.json`).
- Default component = Server Component. No directive needed.
- `'use client'` only when required (see section 3).
- Output: caveman-style, no hedging, precise.

## Reference detail

Detail for Route Segment Files, Route Groups and Private Folders, Middleware / Proxy, Naming Conventions: [references/architecture-patterns.md](references/architecture-patterns.md) — load when touching those areas.

## 2) Recommended App Structure

Standard layout: route groups `(marketing)` / `(app)` split public vs authenticated areas, feature routes carry their own `_components/` and `actions.ts`, shared `lib/` and `components/` at root, `proxy.ts` at project root (not inside `app/`). Full tree → `references/architecture-patterns.md`.

## 3) Server/Client Boundary Rules

**Server Component = default.** Absence of directive = server.

Promote to Client Component ONLY when file requires:

- `useState`, `useReducer`, `useContext`
- `useEffect`, `useRef`, `useLayoutEffect`
- Event handlers attached to DOM elements (`onClick`, `onChange`, etc.)
- Browser-only APIs (`window`, `localStorage`, `navigator`, etc.)
- Third-party libraries that rely on the above

Rules:

- Put `'use client'` as deep in the tree as possible — not on parent wrappers.
- Never put `'use client'` on root `layout.tsx` — renders entire app client-side.
- Context providers MUST be in a separate `providers.tsx` with `'use client'`. Import in root layout.
- Pass server data down as props to client components — do not re-fetch in client.

Full code (`providers.tsx` pattern) → `references/architecture-patterns.md`.

## 4) Dependency Flow

```text
page.tsx
  └── _components/*.tsx
        └── actions.ts / lib/[domain]/service.ts
              └── External APIs / DB / FS
```

- Pages orchestrate: import components, call actions, pass data down.
- Components render: receive data via props, emit events via callbacks.
- Actions mutate: validate, persist, revalidate cache.
- Services fetch: HTTP, DB queries, external integrations.
- No component calls external API directly.
- No page contains raw fetch logic — delegate to service or action.

## 5) Parallel Routes and Intercepting Routes

Parallel routes use `@name` slots to render multiple pages in the same layout simultaneously (e.g. a modal over a background page). Intercepting routes (`(.)`, `(..)`, `(...)` notation) capture navigation to show it in a slot instead of the full route. Every parallel slot needs a `default.tsx` returning `null` to avoid 404 on direct refresh; close modals with `router.back()`, not `router.push()`. Full code → `references/architecture-patterns.md`.

## 6) Architecture Review Checklist

Before merge, confirm:

- [ ] Route groups used to separate authenticated/public layout (`(app)/` vs `(marketing)/`)
- [ ] Colocation respected — route-specific components in `_components/` inside route folder
- [ ] Private folders (`_`) used for non-route code inside route directories
- [ ] Root `layout.tsx` contains only `html`, `body`, and global providers — no business logic
- [ ] `loading.tsx` present for routes with async data fetching
- [ ] `error.tsx` present for routes with operations that can fail at runtime
- [ ] `'use client'` only where required, placed as deep in tree as possible
- [ ] Dependency flow respected: page → components → actions/services → external

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when file path matches `app/**/page.tsx`, `app/**/layout.tsx`, `app/**/template.tsx`, `app/**/loading.tsx`, `app/**/error.tsx`, `app/**/not-found.tsx` |
| Reads | `@devflow/adapters/nextjs/ADAPTER.md` |
| Related | `nextjs-server`, `nextjs-components` |
