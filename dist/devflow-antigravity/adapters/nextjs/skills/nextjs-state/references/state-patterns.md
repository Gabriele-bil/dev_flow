# Next.js State with Zustand — reference detail

Loaded on demand from `../SKILL.md`.

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
