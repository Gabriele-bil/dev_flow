---
name: common-state-patterns
description: Cross-adapter state management guide — Riverpod (Flutter), Signal Store (Angular), Zustand (Next.js). Use when choosing a state solution, designing state architecture, or diagnosing state-related bugs.
---

# Skill: Common State Patterns

Cross-adapter. Use alongside adapter-specific state skill (flutter-riverpod, angular-state, nextjs-state).

## Purpose

Provide a unified mental model for state management across all DevFlow adapters. Prevent over-engineering and under-engineering state. Guide the when-to-choose decision.

## When NOT to Use

- Already in implementation — consult adapter-specific state skill directly
- Single-component local state — use component-local state; no global store needed
- Form state — use adapter-specific form skill (angular-forms, nextjs-forms, flutter-form)

## Choosing a State Scope

Apply this decision tree before writing any state code:

```text
Is the state used by only one component?
  Yes → component-local state (useState, StatefulWidget, local signal)
  No  → Is it shared across sibling components only?
          Yes → lift to parent; prop drilling acceptable for ≤2 levels
          No  → Is it shared across distant/unrelated components?
                  Yes → global/feature store (Riverpod, Signal Store, Zustand)
```

**Rule**: use the smallest scope that satisfies the requirement. Over-scoping state creates coupling.

## Adapter Comparison

### Riverpod (Flutter)

```dart
// Provider definition — outside widget tree
final userProvider = StateNotifierProvider<UserNotifier, UserState>(
  (ref) => UserNotifier(),
);

// Read (no rebuild)
final user = ref.read(userProvider);

// Watch (rebuild on change)
final user = ref.watch(userProvider);

// Notify
ref.read(userProvider.notifier).updateName('Alice');
```

**Pattern**: Notifier owns mutation; widget only reads/watches.
**Scope**: `ProviderScope` at app root; `ProviderContainer` for test isolation.
**Async**: Use `AsyncNotifier` + `AsyncValue` for loading/error/data states.

### Signal Store (Angular)

```typescript
// Store definition
export const UserStore = signalStore(
  withState({ name: '', loading: false }),
  withMethods((store) => ({
    updateName: (name: string) => patchState(store, { name }),
  })),
);

// Component usage
@Component({ providers: [UserStore] }) // feature-scoped
export class UserComponent {
  readonly store = inject(UserStore);
}
```

**Pattern**: Store provides signals + methods; component injects store directly.
**Scope**: Root (`providedIn: 'root'`) for global; component `providers:[]` for feature.
**Computed**: `withComputed` for derived signals — replaces selectors.

### Zustand (Next.js)

```typescript
// Store definition
interface UserState {
  name: string;
  setName: (name: string) => void;
}

const useUserStore = create<UserState>((set) => ({
  name: '',
  setName: (name) => set({ name }),
}));

// Component usage
const name = useUserStore((state) => state.name); // slice selector
```

**Pattern**: `create` defines store; components use slice selectors to prevent over-render.
**Scope**: Module-level store (global); `createStore` + `useStore` for feature-scoped.
**Server**: Zustand is client-side only; server state via React Server Components or SWR/React Query.

## Shared Mental Model

All three solutions share the same conceptual structure:

| Concept | Riverpod | Signal Store | Zustand |
| --------- | ---------- | -------------- | --------- |
| State container | `StateNotifier` | `signalStore` | `create` |
| Read state | `ref.watch` | `store.field` (signal) | `useStore(sel)` |
| Mutate state | notifier method | store method | set / action |
| Derived state | `.select` | `withComputed` | slice selector |
| Async state | `AsyncNotifier` | `withMethods` + RxJS | devtools + middleware |
| Feature scope | `ProviderScope` | component `providers` | `createStore` |
| Test isolation | `ProviderContainer` | `TestBed` overrides | mock store |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Global store for all state | Scope to smallest container that satisfies the requirement |
| Mutating state outside store methods | Always mutate through store-provided methods |
| Deriving state in components | Define derived state in store (`withComputed`, selectors, `.select`) |
| One store for entire application | Feature stores with clear ownership per domain |
| Async state without loading/error/empty | Handle all async states (`AsyncValue`, loading signal, Zustand middleware) |
| Server state in client store (Next.js) | Server state → React Query/SWR; UI state only in Zustand |
| Testing with real store | Inject mock store / `ProviderContainer` per test |

## I/O Reference

| | |
| --- | --- |
| Reads | Adapter-specific state skill (`flutter-riverpod`, `angular-state`, `nextjs-state`) |
| Reads | Active `ADAPTER.md` → **Technology skills → state** |
| Related | `common-clean-code` (SOLID principles applied to state design) |
| Next step | Implement state layer per adapter skill; link back to `plan.md` subtask |
