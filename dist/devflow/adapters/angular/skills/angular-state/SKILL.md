---
name: angular-state
description: Angular NgRx Signal Store — withState, withComputed, withMethods, rxMethod, withEntities. Use for feature stores, async state, derived state, entity CRUD. Triggers on store creation, component→store refactor, or async/entity work.
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

Full store examples (base structure, global vs local, async `rxMethod`, entity CRUD, pure helpers, advanced composition) → [references/state-patterns.md](references/state-patterns.md).

## Checklist

- State interface + `initialState` in same file
- `withProps` for deps
- `withComputed` for derived values
- `withMethods` for commands/mutations
- Async always `loading/error/value`
- `rxMethod` + `tapResponse` for HTTP flows
- `withEntities` for entity CRUD

## I/O Reference

|            |                                                                    |
| ---------- | ------------------------------------------------------------------ |
| Reads      | Active store/feature files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored NgRx Signal Store files                          |
| Invoked by | `devflow.implement`, `devflow.beautify`                            |
