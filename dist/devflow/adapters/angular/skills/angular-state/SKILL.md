---
name: angular-state
description: Angular NgRx Signal Store — withState, withComputed, withMethods, rxMethod, withEntities. Use for feature stores, async state, derived state, entity CRUD. Triggers on store creation, component→store refactor, or async/entity work.
---

# Angular State with NgRx Signal Store

## Purpose

Build global and page state with `@ngrx/signals` `signalStore` — explicit, typed, feature-scoped.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no store, state or facade file touched).
- Form state → `angular-forms` (model signal is the form state).
- Choosing state scope across stacks → `common-state-patterns`; HTTP calls themselves → `angular-http`.

## Store Rules

- Signal Store is the only state library. Do not use `@ngrx/store` (actions/reducers/effects/selectors) or `@ngrx/component-store`.
- Global: `signalStore({ providedIn: 'root' }, …)` in `core/states`. Page: `pages/<page>/state.ts`, provided on `page.ts`.
- Pages/components call the store; the store calls services. Templates never call services.
- State interface + `initialState` constant in the store file.
- Async flows always track `loading`, `error`, `value`.
- Dependencies in `withProps`; derived state in `withComputed`; commands in `withMethods`.
- `rxMethod` for Observable flows, `tapResponse` from `@ngrx/operators` (`next`/`error`/`finalize`) inside the inner stream.
- Entity CRUD → `withEntities` + entity updaters.
- Growing store → pure helpers to page `utils/`, or `signalStoreFeature` split.

Examples (base store, scope table, entities, testing with `unprotected`): [references/state-patterns.md](references/state-patterns.md).

## I/O Reference

|            |                                                                    |
| ---------- | ------------------------------------------------------------------ |
| Reads      | Active store/feature files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored NgRx Signal Store files                          |
| Invoked by | `devflow.implement`, `devflow.beautify`                            |
