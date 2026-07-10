---
name: nextjs-testing
description: Jest + React Testing Library for Next.js — Client/Server Components, Server Actions, API Routes, Zustand stores. Load when touching *.test.tsx, *.test.ts, or __tests__/**.
---

# Next.js Testing

Test Next.js with Jest + React Testing Library. Focus: Client Components, Server Components, Server Actions, API Routes, Zustand stores.

Full code: `references/testing-patterns.md`.

## Baseline

`pnpm add -D jest jest-environment-jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom ts-jest`. Config via `next/jest`, `testEnvironment: 'jsdom'`.

## Required Test Focus

- **Components:** conditional rendering, prop contract, critical accessibility states
- **Forms:** validator behavior, submit disable/enable transitions, server-side error display
- **State (Zustand):** state transitions per action, correct selector output
- **Server Actions:** success/error return for valid/invalid input
- **API Routes:** correct status code per scenario (200, 201, 400, 404, 500)

## Key rules

- Always `userEvent.setup()` — never deprecated `userEvent.click()` direct call
- Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
- Use `waitFor` for async assertions
- Server Components: `render(await ProductList())` — await async component before render
- Server Actions are pure functions — test directly; mock external dependencies (DB, fetch), not the action itself
- Mock `next/navigation` (`useRouter`, `usePathname`, `useSearchParams`, `useParams`) for components using routing hooks

## Coverage

`pnpm test -- --passWithNoTests --watchAll=false --coverage --collectCoverageFrom='src/**/*.{ts,tsx}'`. Threshold: 80% statements, branches, functions, lines. Exclude: `*.stories.tsx`, `*.config.ts`, `app/layout.tsx`, `app/globals.css`.

## Anti-Patterns

- Snapshot tests on complex components — fragile, documents nothing
- Testing implementation details (`wrapper.instance()`, `component.state()`)
- Excessive mocking — mocking everything empties test value
- `fireEvent` instead of `userEvent` — doesn't simulate real user behavior
- Tests without assertions — always-passing tests
- Manual `act()` — `userEvent` wraps in `act` automatically

## I/O Reference

|            |                                                                     |
| ---------- | ------------------------------------------------------------------- |
| Reads      | Active spec/test files, `@devflow/adapters/nextjs/ADAPTER.md`       |
| Writes     | New or refactored Jest + RTL spec files                             |
| Invoked by | `devflow-implement` for `**/*.test.tsx`, `**/*.test.ts`, `**/__tests__/**` |
| Related    | `nextjs-components`, `nextjs-server`, `nextjs-forms`, `nextjs-state` |
