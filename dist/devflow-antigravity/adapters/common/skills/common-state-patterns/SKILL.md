---
name: common-state-patterns
description: Cross-adapter state management guide — Riverpod (Flutter), Signal Store (Angular), Zustand (Next.js). Use when choosing a state solution, designing state architecture, or diagnosing state-related bugs.
---

# Skill: Common State Patterns

Cross-adapter decision guide. Code samples live in the adapter state skill (`flutter-riverpod`, `angular-state`, `nextjs-state`) — on conflict the adapter skill wins.

## Purpose

Pick the smallest state scope and the matching container per stack before writing state code; diagnose state bugs with one shared model.

## When NOT to Use

- File matches no row of the active adapter's `steps/implement.md` → skill load decision matrix that names this skill
- Writing store/provider code — adapter state skill has the API
- Form state — adapter form skill (`angular-forms`, `nextjs-forms`, `flutter-form`)
- Server data in Next.js — Server Components + Next.js cache, not a client store

## Choosing a State Scope

```text
Used by one component?            → local state (Angular `signal()`/`computed()`, React `useState`, Flutter StatefulWidget)
Shared by parent + ≤2 levels down → lift to parent, pass down
Shared by distant components?     → feature store (scoped to feature route/subtree)
Needed app-wide (session, theme)? → global store
```

Smallest scope that satisfies the requirement. Over-scoping = coupling.

## Shared Mental Model

| Concept | Riverpod 3 (codegen) | NgRx Signal Store | Zustand 5 |
| --- | --- | --- | --- |
| Container | `@riverpod class UserNotifier` → `userProvider` (`Notifier` suffix stripped) | `signalStore(withState(…))` | `create<State>()((set) => …)` |
| Read | `ref.watch(userProvider)`; `ref.read` in callbacks | `store.name()` | `useUserStore((s) => s.name)` |
| Mutate | `ref.read(userProvider.notifier).method()` | `withMethods` + `patchState` | action calling `set` |
| Derived | `provider.select(…)` / functional `@riverpod` | `withComputed` | selector; `useShallow` for multi-field |
| Async | `AsyncNotifier` → `AsyncValue`; check `ref.mounted` after `await` | `rxMethod` / `resource()` | async action + `set` (loading/error fields) |
| Global scope | `ProviderScope` at root | `signalStore({ providedIn: 'root' }, …)` | module-level `create` |
| Feature scope | nested `ProviderScope` / overrides | component or route `providers: [Store]` | `createStore` + React context + `useStore` |
| Test | `ProviderContainer.test(overrides: […])` | `TestBed.inject(Store)` | real store, reset to `getInitialState()` per test |

APIs move between minors: check current docs with Context7 before writing store code.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Global store for everything / one app-wide store | Feature stores, one owner per domain |
| Mutation outside store methods | Mutate only through store/notifier methods |
| Derived state computed in components | `withComputed`, selectors, `.select` |
| Async state without loading/error/empty | `AsyncValue`, resource status, explicit fields |
| Server state duplicated in Zustand | Next.js cache owns server data; Zustand = UI state |
| Effect copying state into other state | Derive: `computed()`/`linkedSignal()`, selector, `.select` |
| Mocking the store under test | Real store, fake its dependencies (repository/service); mock the store only in component tests |
| State leaking between tests | Fresh container/`TestBed` per test; Zustand reset in `afterEach` |

## I/O Reference

| | |
| --- | --- |
| Reads | Active `ADAPTER.md` → **Technology skills** (state row); adapter state skill |
| Writes | Nothing — scope/container decision feeds `plan.md` or the implement step |
| Related | `common-clean-code` (dependency direction) |
| Next step | Implement state per adapter state skill |
