---
name: angular-state
description: Build Angular state with NgRx Signal Store using withState, withProps, withComputed, withMethods, rxMethod, and withEntities. Use for global/local feature stores, async state handling, derived state, HTTP orchestration, and entity CRUD. Triggers on store creation, refactoring service-heavy components into stores, adding async loading/error/value state, or implementing entity collections.
---

# Angular State with NgRx Signal Store

Build state with `signalStore`. Keep store explicit, typed, feature-focused.

## Store Rules

- Use Signal Store for global (`providedIn: 'root'`) and local stores.
- Store called by pages/components. Services called by store, not by template.
- Define state interface in same store file.
- Define `initialState` constant in same store file.
- Async flows always track `loading`, `error`, `value`.
- Register services/dependencies in `withProps`.
- Put derived state in `withComputed`.
- Put mutation/commands in `withMethods`.
- Use `rxMethod` for HTTP/service observable flows.
- Use `tapResponse` from `@ngrx/operators` for `next/error/finalize`.
- When store file grows too much, extract pure helpers to `utils` in feature folder.
- For entity CRUD, use `withEntities` + entity updaters.

## Base Store Structure

```typescript
import { computed, inject } from "@angular/core";
import {
  patchState,
  signalStore,
  withComputed,
  withMethods,
  withProps,
  withState,
} from "@ngrx/signals";

interface UsersState {
  users: User[];
  loading: boolean;
  error: string | null;
  selectedId: string | null;
}

const initialState: UsersState = {
  users: [],
  loading: false,
  error: null,
  selectedId: null,
};

export const UsersStore = signalStore(
  { providedIn: "root" },
  withState(initialState),
  withProps(() => ({
    usersService: inject(UsersService),
  })),
  withComputed((store) => ({
    selectedUser: computed(
      () => store.users().find((u) => u.id === store.selectedId()) ?? null,
    ),
    hasError: computed(() => !!store.error()),
  })),
  withMethods((store) => ({
    selectUser(id: string) {
      patchState(store, { selectedId: id });
    },
    clearError() {
      patchState(store, { error: null });
    },
  })),
);
```

## Global vs Local Store

```typescript
// Global store
export const AuthStore = signalStore(
  { providedIn: "root" },
  withState(initialState),
);

// Local store (per component instance)
export const WizardStore = signalStore(withState(wizardInitialState));

@Component({
  template: `...`,
  providers: [WizardStore],
})
export class WizardPage {
  store = inject(WizardStore);
}
```

## Async Methods with `rxMethod` + `tapResponse`

Use `rxMethod` for service HTTP pipelines. Always set `loading/error/value`.

```typescript
import { inject } from "@angular/core";
import {
  patchState,
  signalStore,
  withMethods,
  withProps,
  withState,
} from "@ngrx/signals";
import { rxMethod } from "@ngrx/signals/rxjs-interop";
import { tapResponse } from "@ngrx/operators";
import { debounceTime, distinctUntilChanged, pipe, switchMap, tap } from "rxjs";

interface SearchState {
  value: Book[];
  loading: boolean;
  error: string | null;
}

const searchInitialState: SearchState = {
  value: [],
  loading: false,
  error: null,
};

export const BookSearchStore = signalStore(
  withState(searchInitialState),
  withProps(() => ({
    booksService: inject(BooksService),
  })),
  withMethods((store) => ({
    loadByQuery: rxMethod<string>(
      pipe(
        debounceTime(300),
        distinctUntilChanged(),
        tap(() => patchState(store, { loading: true, error: null })),
        switchMap((query) =>
          store.booksService.getByQuery(query).pipe(
            tapResponse({
              next: (value) => patchState(store, { value, loading: false }),
              error: (err: unknown) =>
                patchState(store, {
                  loading: false,
                  error: err instanceof Error ? err.message : "Request failed",
                }),
            }),
          ),
        ),
      ),
    ),
  })),
);
```

## Entity CRUD with `withEntities`

Use for normalized entity collections.

```typescript
import { patchState, signalStore, withMethods } from "@ngrx/signals";
import {
  addEntity,
  removeEntities,
  setAllEntities,
  updateAllEntities,
  withEntities,
} from "@ngrx/signals/entities";

type Todo = { id: number; text: string; completed: boolean };

export const TodosStore = signalStore(
  withEntities<Todo>(),
  withMethods((store) => ({
    setTodos(todos: Todo[]) {
      patchState(store, setAllEntities(todos));
    },
    addTodo(todo: Todo) {
      patchState(store, addEntity(todo));
    },
    completeAll() {
      patchState(store, updateAllEntities({ completed: true }));
    },
    removeEmpty() {
      patchState(
        store,
        removeEntities(({ text }) => !text.trim()),
      );
    },
  })),
);
```

## Pure Helpers in `utils`

If `withMethods` gets noisy, move pure transformations to `utils`.

```typescript
// utils/users-state.utils.ts
export function mergeUsers(existing: User[], incoming: User[]): User[] {
  const map = new Map(existing.map((u) => [u.id, u]));
  for (const user of incoming) map.set(user.id, user);
  return Array.from(map.values());
}
```

```typescript
// store file
patchState(store, (state) => ({
  users: mergeUsers(state.users, users),
}));
```

## Checklist

- State interface + `initialState` in same file
- `withProps` for deps
- `withComputed` for derived values
- `withMethods` for commands/mutations
- Async always `loading/error/value`
- `rxMethod` + `tapResponse` for HTTP flows
- `withEntities` for entity CRUD

For advanced patterns, see [references/state-patterns.md](references/state-patterns.md).

## I/O Reference

|            |                                                                    |
| ---------- | ------------------------------------------------------------------ |
| Reads      | Active store/feature files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored NgRx Signal Store files                          |
| Invoked by | `devflow.implement`, `devflow.beautify`                            |
