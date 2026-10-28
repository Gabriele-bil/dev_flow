# Angular State Patterns (NgRx Signal Store)

## Table of Contents

- [Base Store Structure](#base-store-structure)
- [Global vs Local Store](#global-vs-local-store)
- [Async Methods with rxMethod + tapResponse](#async-methods-with-rxmethod--tapresponse)
- [Entity CRUD with withEntities](#entity-crud-with-withentities)
- [Pure Helpers in utils](#pure-helpers-in-utils)
- [Feature Store Composition](#feature-store-composition)
- [Entity Workflows](#entity-workflows)
- [Async Orchestration with rxMethod](#async-orchestration-with-rxmethod)
- [Error Normalization](#error-normalization)
- [Local Store Pattern](#local-store-pattern)
- [Testing Signal Store](#testing-signal-store)

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

## Feature Store Composition

Split feature state by concern. Compose signals, do not build one giant store.

```typescript
interface OrdersState {
  value: Order[];
  loading: boolean;
  error: string | null;
  filters: { status: 'all' | 'open' | 'closed'; query: string };
}

const initialState: OrdersState = {
  value: [],
  loading: false,
  error: null,
  filters: { status: 'all', query: '' },
};

export const OrdersStore = signalStore(
  { providedIn: 'root' },
  withState(initialState),
  withComputed((store) => ({
    filteredOrders: computed(() => {
      const { status, query } = store.filters();
      return store.value().filter((order) => {
        const statusOk = status === 'all' || order.status === status;
        const queryOk = !query || order.customerName.toLowerCase().includes(query.toLowerCase());
        return statusOk && queryOk;
      });
    }),
  })),
  withMethods((store) => ({
    setStatus(status: OrdersState['filters']['status']) {
      patchState(store, (state) => ({ filters: { ...state.filters, status } }));
    },
    setQuery(query: string) {
      patchState(store, (state) => ({ filters: { ...state.filters, query } }));
    },
  }))
);
```

## Entity Workflows

Use entity updaters for CRUD intent clarity.

```typescript
import { patchState, signalStore, withMethods } from '@ngrx/signals';
import {
  addEntity,
  removeEntities,
  setAllEntities,
  updateAllEntities,
  withEntities,
} from '@ngrx/signals/entities';

type Product = { id: string; name: string; price: number; active: boolean };

export const ProductsStore = signalStore(
  withEntities<Product>(),
  withMethods((store) => ({
    replaceAll(products: Product[]) {
      patchState(store, setAllEntities(products));
    },
    create(product: Product) {
      patchState(store, addEntity(product));
    },
    deactivateAll() {
      patchState(store, updateAllEntities({ active: false }));
    },
    removeInactive() {
      patchState(store, removeEntities(({ active }) => !active));
    },
  }))
);
```

## Async Orchestration with `rxMethod`

Standard flow: debounce/filter -> loading on -> switchMap -> `tapResponse`.

```typescript
import { inject } from '@angular/core';
import { patchState, signalStore, withMethods, withProps, withState } from '@ngrx/signals';
import { rxMethod } from '@ngrx/signals/rxjs-interop';
import { tapResponse } from '@ngrx/operators';
import { debounceTime, distinctUntilChanged, filter, pipe, switchMap, tap } from 'rxjs';

interface CatalogState {
  value: Product[];
  loading: boolean;
  error: string | null;
}

const initialState: CatalogState = {
  value: [],
  loading: false,
  error: null,
};

export const CatalogStore = signalStore(
  withState(initialState),
  withProps(() => ({ catalogService: inject(CatalogService) })),
  withMethods((store) => ({
    search: rxMethod<string>(
      pipe(
        debounceTime(250),
        distinctUntilChanged(),
        filter((query) => query.length >= 2),
        tap(() => patchState(store, { loading: true, error: null })),
        switchMap((query) =>
          store.catalogService.search(query).pipe(
            tapResponse({
              next: (value) => patchState(store, { value, loading: false }),
              error: (err) => patchState(store, { loading: false, error: normalizeError(err) }),
            })
          )
        )
      )
    ),
  }))
);
```

## Error Normalization

Normalize once, reuse everywhere.

```typescript
export function normalizeError(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (typeof err === 'string') return err;
  return 'Unknown error';
}
```

## Local Store Pattern

Per-page state. Isolated lifetime. Cleaner tests.

```typescript
export const CheckoutStore = signalStore(
  withState({
    step: 1,
    value: null as CheckoutData | null,
    loading: false,
    error: null as string | null,
  })
);

@Component({
  selector: 'app-checkout-page',
  providers: [CheckoutStore],
  template: `...`,
})
export class CheckoutPage {
  store = inject(CheckoutStore);
}
```

## Testing Signal Store

Test methods and derived state directly.

```typescript
describe('OrdersStore', () => {
  let store: InstanceType<typeof OrdersStore>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [OrdersStore],
    });
    store = TestBed.inject(OrdersStore);
  });

  it('updates query filter', () => {
    store.setQuery('john');
    expect(store.filters().query).toBe('john');
  });

  it('computes filtered orders', () => {
    patchState(store, {
      value: [
        { id: '1', customerName: 'John', status: 'open' },
        { id: '2', customerName: 'Ana', status: 'closed' },
      ] as Order[],
      filters: { status: 'open', query: '' },
    });

    expect(store.filteredOrders().length).toBe(1);
  });
});
```
