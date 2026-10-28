# Skill: Common State Patterns — reference detail

Loaded on demand from `../SKILL.md`.

## Riverpod (Flutter)

```dart
// Provider definition with @riverpod codegen
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  UserState build() => const UserState(name: '');

  void updateName(String name) {
    state = state.copyWith(name: name);
  }
}

// Read (one-shot in callbacks)
final user = ref.read(userNotifierProvider);

// Watch (rebuild on change)
final user = ref.watch(userNotifierProvider);

// Mutate
ref.read(userNotifierProvider.notifier).updateName('Alice');
```

**Pattern**: Notifier owns mutation; widget only reads/watches via `ref`.
**Scope**: `ProviderScope` at app root; `ProviderContainer` for test isolation.
**Async**: Use `AsyncNotifier` + `AsyncValue` (`.skeleton(mock:)` extension) for loading/error/data states.

## Signal Store (Angular)

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

## Zustand (Next.js)

```typescript
// Store definition (curried create for TypeScript)
interface UserState {
  name: string;
  setName: (name: string) => void;
}

export const useUserStore = create<UserState>()((set) => ({
  name: '',
  setName: (name) => set({ name }),
}));

// Component usage: granular selector
const name = useUserStore((state) => state.name);

// Multi-property selector requires useShallow (Zustand 5) to prevent infinite re-renders:
import { useShallow } from 'zustand/react/shallow';
const { name, setName } = useUserStore(
  useShallow((state) => ({ name: state.name, setName: state.setName }))
);
```

**Pattern**: `create` defines store; components use slice selectors (or `useShallow`) to prevent over-render.
**Scope**: Module-level store (global); `createStore` + `useStore` for feature-scoped.
**Server**: Zustand is client-side only; server state is fetched in Server Components and managed via Next.js cache and Server Actions. Never duplicate server cache in Zustand.
