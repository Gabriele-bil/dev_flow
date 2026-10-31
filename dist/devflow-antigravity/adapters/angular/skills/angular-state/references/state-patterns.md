# Angular State (NgRx Signal Store) — project decisions

Loaded on demand from `../SKILL.md`. `@ngrx/signals` API (features, entity updaters, `withResource`, events plugin): check current docs with Context7 (`/websites/ngrx_io_guide_signals`) before using anything beyond the base below.

## Scope

| State | Where | Provided |
| --- | --- | --- |
| Cross-page (auth, session, flags) | `core/states/*.ts` | `signalStore({ providedIn: 'root' }, …)` |
| One page | `pages/<page>/state.ts` | `providers: [PageStore]` on `page.ts` — dies with the page |
| One component, trivial | `signal()`/`computed()` in the component | — |

Scope choice across stacks: `common-state-patterns`.

## Base store

```typescript
interface UsersState { value: User[]; loading: boolean; error: string | null; selectedId: string | null }
const initialState: UsersState = { value: [], loading: false, error: null, selectedId: null };

export const UsersStore = signalStore(
  withState(initialState),
  withProps(() => ({ usersService: inject(UsersService) })),
  withComputed((store) => ({
    selected: computed(() => store.value().find((u) => u.id === store.selectedId()) ?? null),
  })),
  withMethods((store) => ({
    select(id: string) { patchState(store, { selectedId: id }); },
    load: rxMethod<string>(pipe(
      debounceTime(300),
      tap(() => patchState(store, { loading: true, error: null })),
      switchMap((q) => store.usersService.search(q).pipe(tapResponse({
        next: (value) => patchState(store, { value }),
        error: (err) => patchState(store, { error: normalizeError(err) }),
        finalize: () => patchState(store, { loading: false }),
      }))),
    )),
  })),
);
```

Decisions shown: state interface + `initialState` in the store file; deps in `withProps`; `rxMethod` + `tapResponse` (`@ngrx/operators`) with error handling inside the inner stream; `loading/error/value` on every async flow; one `normalizeError()` in `shared/utils`.

## Entities

Collections with CRUD → `withEntities<T>()` + updaters (`setAllEntities`, `addEntity`, `updateEntity`, `removeEntities`). No hand-rolled arrays + `find`/`map` for CRUD.

## Size

Store over ~200 lines → extract pure helpers to page `utils/`, or split by concern with `signalStoreFeature`. Never one giant global store.

## Testing

`TestBed.configureTestingModule({ providers: [Store, { provide: Service, useValue: mock }] })`, call methods, assert signals. State is protected: seed with `patchState(unprotected(store), …)` from `@ngrx/signals/testing`.
