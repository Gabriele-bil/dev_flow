---
name: nextjs-testing
description: Jest + React Testing Library for Next.js — Client Components, sync Server Components, Server Actions, Route Handlers, Zustand stores; Playwright for async Server Components and flows. Load when touching *.test.tsx, *.test.ts, __tests__/**, or e2e/**.
---

# Next.js Testing

## Purpose

Test rules for Next.js: Jest + RTL via `next/jest` for units, Playwright for async Server Components and user flows. Config and examples: `references/testing-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Coverage threshold, test placement, commands → `steps/test.md` (SSOT)
- Code under test itself → skill for that file type

## Baseline

Dev deps from `steps/setup.md`: `jest`, `jest-environment-jsdom`, `@testing-library/react`, `@testing-library/dom`, `@testing-library/jest-dom`, `@testing-library/user-event`, `@types/jest`, `ts-node`, `@playwright/test`. Config via `next/jest.js` (SWC transform; do not use `ts-jest`).

## Required focus

- **Components:** conditional rendering, prop contract, accessibility states.
- **Forms:** validation messages, submit disabled while pending, server error display.
- **Stores:** transitions per action, selector output (real store, reset per test — see `nextjs-state`).
- **Server Actions:** success / validation error / failure result for given input.
- **Route Handlers:** status per scenario — `200`, `201`, `400` (invalid body), `404`, `500`. Same codes as `nextjs-server`.

## Rules

- `const user = userEvent.setup()` then `await user.click(...)`; no `fireEvent` for user interactions.
- Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`.
- `findBy*` / `waitFor` for async; no manual `act()`.
- Async Server Components: Jest cannot render them → cover with Playwright; unit-test sync children and extracted `lib/` logic.
- Server Actions and Route Handlers: call directly; mock DB / external fetch and `next/cache` (`updateTag`, `revalidateTag`, `refresh`), never the function under test.
- Mock `next/navigation` hooks for components that use them.
- Coverage collected from `app/`, `components/`, `lib/` (no `src/` dir).

## Anti-Patterns

- Snapshots of complex components — fragile, assert nothing specific.
- Testing implementation details (internal state, private functions).
- Mocking everything — test proves only the mocks.
- Tests without assertions.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` / `devflow-test` via `steps/implement.md` → skill load decision matrix (`**/*.test.ts(x)`, `**/__tests__/**`, `e2e/**`) |
| Reads | `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/nextjs/steps/test.md`, `references/testing-patterns.md` |
| Writes | Jest + RTL specs, Playwright specs |
| Related | `nextjs-components`, `nextjs-server`, `nextjs-forms`, `nextjs-state` |
