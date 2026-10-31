---
name: nextjs-state
description: Zustand 5 stores in Next.js — naming, selectors with useShallow, persist, testing with real stores. Load when touching store.ts, *Store.ts, or use*Store.ts files.
---

# Next.js State with Zustand

## Purpose

Next.js-specific Zustand rules. Scope decision (local vs lifted vs global) and cross-stack mental model: `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/common-state-patterns/SKILL.md` — read it first when introducing a new store. Middleware examples: `references/state-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Server data (profile, posts, products) → `nextjs-server` (Server Components + `'use cache'`), never a store
- Form field state → `nextjs-forms` (React Hook Form)

## Where state lives (Next.js)

| State | Where |
| --- | --- |
| Server data | Server Component + Next.js cache |
| Transient UI (modal open) | `useState` in component |
| Global UI (sidebar, selected tab) | Zustand store |
| Filters, page, sort | URL (`searchParams` / `useSearchParams`) |
| Auth session | Auth provider, read on server |
| Persistent cart / preferences | Zustand + `persist` |

## Rules

- Name `use<Feature>Store`, file `lib/stores/<feature>-store.ts`. One store per domain.
- `create<State>()((set) => ({ … }))` — curried form for typing.
- Select a single slice: `useUIStore((s) => s.sidebarOpen)`. Multiple values → `useShallow` from `zustand/shallow`; object selector without `useShallow` loops re-renders in Zustand 5.
- Mutate only via `set` inside store actions.
- Store is client-only: never import into Server Components, never seed it from module scope on the server (shared across requests). Per-request initial data → `createStore` + React context provider in a Client Component.
- `persist` only for state that must survive reload; reading persisted state during render → hydration mismatch, gate with `useEffect` or `skipHydration`.

## Testing (overrides `common-state-patterns` "inject mock store" row for Next.js)

Use real stores. Reset in `beforeEach` with `useXStore.setState(useXStore.getInitialState(), true)`; seed component tests with `setState`. Do not mock store hooks — mocks hide selector bugs.

## Review Checklist

- [ ] `use<Feature>Store` naming, one domain per store
- [ ] Single-slice selectors or `useShallow`
- [ ] No server data in store
- [ ] `persist` justified; hydration gated
- [ ] Tests reset real store with `getInitialState()`

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`**/store.ts`, `**/*Store.ts`, `**/use*Store.ts`, `lib/stores/**`) |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/common/skills/common-state-patterns/SKILL.md`, `references/state-patterns.md` |
| Writes | Zustand stores and their tests |
| Related | `nextjs-components`, `nextjs-server`, `nextjs-testing` |
