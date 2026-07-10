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

- Next.js 15+ App Router. No Pages Router.
- TypeScript strict mode (`"strict": true` in `tsconfig.json`).
- Default component = Server Component. No directive needed.
- `'use client'` only when absolutely required (see section 5).
- Output: caveman-style, no hedging, precise.

## 2) Route Segment Files

Each route folder can contain these reserved filenames:

| File | Purpose |
| --- | --- |
| `page.tsx` | Route leaf — makes URL publicly accessible |
| `layout.tsx` | Persistent wrapper — wraps page and children, does NOT re-mount on navigation |
| `loading.tsx` | Automatic Suspense boundary — shows while page/children stream |
| `error.tsx` | Error boundary with `reset` prop — catches runtime errors in subtree |
| `global-error.tsx` | Error boundary for root layout — must include `<html>` and `<body>` tags |
| `not-found.tsx` | Renders when `notFound()` is called within subtree |
| `template.tsx` | Like layout but re-mounts on every navigation — use when fresh state per nav is required |
| `default.tsx` | Fallback for parallel route slots — return `null` when slot is inactive |
| `route.ts` | API Route handler — no UI, named exports only (`GET`, `POST`, etc.) |
| `opengraph-image.tsx` | Auto-generated OG image for route — runs on Edge runtime |
| `twitter-image.tsx` | Auto-generated Twitter card image — runs on Edge runtime |

Rules:

- `layout.tsx` receives `children: React.ReactNode` — never fetch data that changes per-page inside root layout.
- `error.tsx` MUST be a Client Component (`'use client'`). Receives `error` and `reset` props.
- `global-error.tsx` MUST be a Client Component AND include `<html><body>` tags — replaces root layout on error.
- `loading.tsx` wraps `page.tsx` in `<Suspense>` automatically — no manual wrapping needed.
- `template.tsx` use case: tabs with per-tab animation, forms that must reset, auth-check per navigation.

## 3) Route Groups and Private Folders

**Route groups** — parentheses: `(group-name)/`

- Organize routes without adding URL segment.
- Each group can have its own `layout.tsx`.
- Use to split authenticated vs public layout.

**Private folders** — underscore: `_folder-name/`

- Excluded from routing system entirely.
- Use for components, hooks, lib co-located with a route but not routes themselves.

## 4) Recommended App Structure

Standard layout: route groups `(marketing)` / `(app)` split public vs authenticated areas, feature routes carry their own `_components/` and `actions.ts`, shared `lib/` and `components/` at root, `middleware.ts` at project root (not inside `app/`). Full tree → `references/architecture-patterns.md`.

## 5) Server/Client Boundary Rules

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

## 6) Dependency Flow

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

## 7) Middleware / Proxy

File at **project root** (sibling to `app/`, `lib/`, `components/`). Never inside `app/`.

Next.js 16+ renamed `middleware.ts` → `proxy.ts` (codemod: `npx @next/codemod@latest upgrade`):

| Version | File | Export | Matcher config |
| --- | --- | --- | --- |
| 14–15 | `middleware.ts` | `middleware()` | `config` |
| 16+ | `proxy.ts` | `proxy()` | `proxyConfig` |

Full code for both versions → `references/architecture-patterns.md`.

## 8) Naming Conventions

| Target | Convention | Example |
| --- | --- | --- |
| Folders / files | kebab-case | `user-profile/`, `user-card.tsx` |
| React components | PascalCase (function name) | `export function UserCard()` |
| Utility functions | camelCase | `formatDate()`, `parseSlug()` |
| Server Actions files | `actions.ts` | `app/dashboard/actions.ts` |
| API route handlers | `route.ts` | `app/api/users/route.ts` |
| Private folders | `_` prefix | `_components/`, `_lib/`, `_hooks/` |
| Route groups | `()` wrapping | `(marketing)/`, `(app)/` |
| Dynamic segments | `[]` wrapping | `[slug]/`, `[id]/` |
| Catch-all segments | `[...]` wrapping | `[...slug]/` |

## 9) Parallel Routes and Intercepting Routes

Parallel routes use `@name` slots to render multiple pages in the same layout simultaneously (e.g. a modal over a background page). Intercepting routes (`(.)`, `(..)`, `(...)` notation) capture navigation to show it in a slot instead of the full route. Every parallel slot needs a `default.tsx` returning `null` to avoid 404 on direct refresh; close modals with `router.back()`, not `router.push()`. Full code → `references/architecture-patterns.md`.

## 10) Architecture Review Checklist

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
