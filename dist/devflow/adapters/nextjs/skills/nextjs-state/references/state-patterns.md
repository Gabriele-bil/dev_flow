# Next.js State with Zustand — project patterns

Loaded on demand from `../SKILL.md`. Middleware options change between minors: check current Zustand docs with Context7 before using one not shown here.

## Base store

```ts
// lib/stores/ui-store.ts
import { create } from 'zustand'

interface UIState {
  sidebarOpen: boolean
  toggleSidebar: () => void
}

export const useUIStore = create<UIState>()((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
}))
```

## Multi-value selector

```ts
import { useShallow } from 'zustand/shallow'

const { sidebarOpen, toggleSidebar } = useUIStore(
  useShallow((s) => ({ sidebarOpen: s.sidebarOpen, toggleSidebar: s.toggleSidebar })),
)
```

## Persist

```ts
import { persist } from 'zustand/middleware'

export const useCartStore = create<CartState>()(
  persist((set) => ({ items: [], addItem: (item) => set((s) => ({ items: [...s.items, item] })) }), {
    name: 'cart',
  }),
)
```

## Test reset

```ts
beforeEach(() => {
  useCartStore.setState(useCartStore.getInitialState(), true)
})
```
