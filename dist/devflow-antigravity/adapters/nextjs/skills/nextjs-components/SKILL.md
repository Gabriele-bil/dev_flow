---
name: nextjs-components
description: "'use client' components — React 19 hooks, interactivity, context providers, hydration errors. Load when touching files with 'use client' directive."
---

# Next.js Client Components

## Purpose

Rules for `'use client'` files: minimal boundary, React 19 primitives, serializable props, hydration safety. Short examples: `references/components-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Server Component or Server Action → `nextjs-server`
- Form wiring (RHF + Zod + shadcn `Field`) → `nextjs-forms`; Zustand store files → `nextjs-state`

## Baseline

Next.js 16, React 19.3, TypeScript strict.

## When `'use client'`

Only if file uses state/effect/ref hooks, DOM event handlers, browser APIs (`window`, `localStorage`), or `next/navigation` client hooks. Place at lowest leaf — every import below a `'use client'` file ships to browser.

## React 19 rules

- `ref` is a regular prop — do not use `forwardRef` in new code (unnecessary in React 19, slated for deprecation).
- `use(promise)` unwraps Promise props (e.g. `params` passed from a page) inside Client Components.
- `useActionState(action, initialState)` → `[state, formAction, isPending]`; initial state type must match action's return type (include `null` in the union when starting from `null`).
- `useFormStatus` (`react-dom`) for pending state in nested submit buttons.
- `useOptimistic` for instant UI before server confirmation.
- `useId()` for element ids — never `Math.random()`.

## Server → Client props

- Serializable only: primitives, plain objects/arrays, Server Actions. `Date` → ISO string; `Map`/`Set` → object/array; class instance → plain object.
- No functions as props from server (except Server Actions).
- No `async` Client Components — fetch in parent Server Component.
- Never import Server Component into Client Component — pass it as `children`.

## Navigation hooks

From `next/navigation` only (`next/router` is Pages Router — never use). `useSearchParams()` needs a `<Suspense>` boundary around the leaf using it, otherwise the page falls back to client rendering.

## Hydration

Mismatch causes: time/random during render, browser APIs during render, invalid nesting (`<div>` in `<p>`), theme class. Fix: move to `useEffect` / client state, `useId`, `suppressHydrationWarning` on `<html>` only (next-themes).

## Anti-Patterns

- `'use client'` on root `layout.tsx` or whole `page.tsx`.
- `useEffect` for initial data fetch — Server Component instead.
- Providers scattered across tree — one `app/providers.tsx`.

## Review Checklist

- [ ] `'use client'` only where needed, deepest level
- [ ] Props from server serializable
- [ ] `useSearchParams` leaves wrapped in `<Suspense>`
- [ ] No `forwardRef`, no `Math.random()` ids

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (files with `'use client'`) |
| Reads | `references/components-patterns.md` |
| Writes | Client Components, `app/providers.tsx` |
| Related | `nextjs-architecture`, `nextjs-server`, `nextjs-state`, `nextjs-forms` |
