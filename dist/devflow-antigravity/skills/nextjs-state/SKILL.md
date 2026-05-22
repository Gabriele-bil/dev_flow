---
name: nextjs-state
description: Zustand client state management — stores, middleware, selectors, and decision matrix for choosing state location. Load when touching store.ts, *Store.ts, or use*Store.ts files.
---

# Next.js State with Zustand

Manage client-only global state with Zustand. Next.js cache handles server state — never duplicate in store.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Fundamental Rule

Zustand = client state only. Server data (user profile, posts, products) lives in Server Components + Next.js cache. Never put fetched server data in Zustand.

## Decision Matrix

| State type | Where |
|---|---|
| Server data (user profile, posts, products) | Server Component fetch + Next.js cache |
| UI transient (modal open, accordion expanded) | `useState` local to component |
| UI global (sidebar collapsed, selected tab) | Zustand store |
| Form data (field values, errors) | React Hook Form |
| URL-driven (filters, page, sort) | `useSearchParams` + URL |
| Auth session | next-auth / dedicated auth provider |
| Shopping cart (persistent) | Zustand + `persist` middleware |

## Base Store Pattern

```ts
// lib/stores/ui-store.ts
import { create } from 'zustand'

interface UIState {
  sidebarOpen: boolean
  toggleSidebar: () => void
  setSidebarOpen: (open: boolean) => void
}

export const useUIStore = create<UIState>()((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  setSidebarOpen: (open) => set({ sidebarOpen: open }),
}))
```

## Naming Convention

Always `use[Feature]Store`: `useUIStore`, `useCartStore`, `useNotificationStore`.

## Optimized Selectors

Subscribe only to the required slice — never the entire store.

```ts
// ✅ Subscribe only to sidebarOpen
const sidebarOpen = useUIStore((state) => state.sidebarOpen)

// ❌ Subscribe to entire store (re-renders on every change)
const store = useUIStore()
```

## Middleware `persist`

For state that must survive page refresh — stored in localStorage.

```ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface CartState {
  items: CartItem[]
  addItem: (item: CartItem) => void
  removeItem: (id: string) => void
}

export const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      items: [],
      addItem: (item) => set((state) => ({ items: [...state.items, item] })),
      removeItem: (id) => set((state) => ({ items: state.items.filter(i => i.id !== id) })),
    }),
    { name: 'cart-storage' }
  )
)
```

## Middleware `immer`

For complex updates on nested state — direct mutation syntax.

```ts
import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

export const useComplexStore = create<State>()(
  immer((set) => ({
    // state...
    updateNested: (id, value) => set((state) => {
      state.nested[id].value = value  // direct mutation via immer
    }),
  }))
)
```

## Store Slice Pattern

Split large stores into domain slices, combine in main store.

```ts
// lib/stores/slices/ui-slice.ts
export const createUISlice = (set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
})

// lib/stores/app-store.ts
export const useAppStore = create()((...a) => ({
  ...createUISlice(...a),
  ...createNotificationSlice(...a),
}))
```

## Testing Zustand

Reset store between tests with `setState`. Use real state with overrides — do not mock Zustand.

```ts
beforeEach(() => {
  useUIStore.setState({ sidebarOpen: false })
})
```

## Anti-patterns

- Store as database cache — Zustand is not a server data layer
- Monolithic store — prefer one store per domain
- Direct mutation without `set` — always use `set`
- Subscribe to entire store — always use selectors
- Initialize store from Server Component — store is client-only

## Review Checklist

- [ ] Naming: `use[Feature]Store`
- [ ] Granular selector (not entire store)
- [ ] No server data in store
- [ ] `persist` only for state that must survive refresh
- [ ] Store testable with `setState` reset

## I/O Reference

|            |                                                                  |
| ---------- | ---------------------------------------------------------------- |
| Invoked by | `devflow-implement` for `**/store.ts`, `**/*Store.ts`, `**/use*Store.ts` |
| Related    | `nextjs-components`, `nextjs-server`                             |
