---
name: nextjs-testing
description: Jest + React Testing Library for Next.js — Client Components, Server Components, Server Actions, API Routes, and Zustand stores. Load when touching *.test.tsx, *.test.ts, or __tests__/** files.
---

# Next.js Testing

Test Next.js with Jest + React Testing Library. Focus: Client Components, Server Components, Server Actions, API Routes, Zustand stores.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Baseline

```bash
pnpm add -D jest jest-environment-jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom ts-jest
```

## Jest Config

```ts
// jest.config.ts
import type { Config } from 'jest'
import nextJest from 'next/jest'

const createJestConfig = nextJest({ dir: './' })

const config: Config = {
  testEnvironment: 'jsdom',
  setupFilesAfterFramework: ['<rootDir>/jest.setup.ts'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/$1',
  },
}

export default createJestConfig(config)
```

```ts
// jest.setup.ts
import '@testing-library/jest-dom'
```

## Testing Client Components

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Counter } from './counter'

describe('Counter', () => {
  it('increments on click', async () => {
    const user = userEvent.setup()
    render(<Counter initialCount={0} />)

    await user.click(screen.getByRole('button', { name: /increment/i }))

    expect(screen.getByText('1')).toBeInTheDocument()
  })
})
```

- Always `userEvent.setup()` — never deprecated `userEvent.click()` direct call
- Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
- Use `waitFor` for async assertions

## Testing Server Components

```tsx
import { render, screen } from '@testing-library/react'
import { ProductList } from './product-list'

// Mock fetch for Server Component
global.fetch = jest.fn().mockResolvedValue({
  ok: true,
  json: async () => [{ id: '1', name: 'Product A' }],
})

describe('ProductList', () => {
  it('renders products', async () => {
    render(await ProductList())  // await async component
    expect(screen.getByText('Product A')).toBeInTheDocument()
  })
})
```

## Mock `next/navigation`

```ts
jest.mock('next/navigation', () => ({
  useRouter: () => ({
    push: jest.fn(),
    replace: jest.fn(),
    back: jest.fn(),
  }),
  usePathname: () => '/dashboard',
  useSearchParams: () => new URLSearchParams(),
  useParams: () => ({ id: '123' }),
}))
```

## Testing Server Actions

```ts
import { createItem } from './actions'

describe('createItem', () => {
  it('returns error for invalid input', async () => {
    const result = await createItem({ name: '' })
    expect(result.success).toBe(false)
    expect(result.error).toBeDefined()
  })

  it('returns success for valid input', async () => {
    const result = await createItem({ name: 'Test Item' })
    expect(result.success).toBe(true)
  })
})
```

- Server Actions are pure functions — test directly
- Mock external dependencies (DB, fetch), not the action itself

## Testing API Routes

```ts
import { GET, POST } from './route'
import { NextRequest } from 'next/server'

describe('GET /api/items', () => {
  it('returns items list', async () => {
    const request = new NextRequest('http://localhost/api/items')
    const response = await GET(request)
    const data = await response.json()

    expect(response.status).toBe(200)
    expect(Array.isArray(data)).toBe(true)
  })
})

describe('POST /api/items', () => {
  it('returns 400 for invalid body', async () => {
    const request = new NextRequest('http://localhost/api/items', {
      method: 'POST',
      body: JSON.stringify({ name: '' }),
    })
    const response = await POST(request)
    expect(response.status).toBe(400)
  })
})
```

## Testing Zustand Stores

```ts
import { useCartStore } from '@/lib/stores/cart-store'

describe('cartStore', () => {
  beforeEach(() => {
    useCartStore.setState({ items: [] })
  })

  it('adds item correctly', () => {
    useCartStore.getState().addItem({ id: '1', name: 'Product', price: 10 })
    expect(useCartStore.getState().items).toHaveLength(1)
  })
})
```

## Testing React Hook Form

```tsx
it('shows validation error on empty submit', async () => {
  const user = userEvent.setup()
  render(<ProfileForm />)

  await user.click(screen.getByRole('button', { name: /save/i }))

  expect(await screen.findByText(/name required/i)).toBeInTheDocument()
})

it('submits with valid data', async () => {
  const user = userEvent.setup()
  const mockAction = jest.fn().mockResolvedValue({ success: true })
  render(<ProfileForm onSubmit={mockAction} />)

  await user.type(screen.getByLabelText(/name/i), 'John Doe')
  await user.type(screen.getByLabelText(/email/i), 'john@example.com')
  await user.click(screen.getByRole('button', { name: /save/i }))

  await waitFor(() => expect(mockAction).toHaveBeenCalledWith({
    name: 'John Doe',
    email: 'john@example.com',
  }))
})
```

## Coverage

```bash
pnpm test -- --passWithNoTests --watchAll=false --coverage --collectCoverageFrom='src/**/*.{ts,tsx}'
```

- Threshold: 80% statements, branches, functions, lines
- Exclude: `*.stories.tsx`, `*.config.ts`, `app/layout.tsx`, `app/globals.css`

## Required Test Focus

- **Components:** conditional rendering, prop contract, critical accessibility states
- **Forms:** validator behavior, submit disable/enable transitions, server-side error display
- **State (Zustand):** state transitions per action, correct selector output
- **Server Actions:** success/error return for valid/invalid input
- **API Routes:** correct status code per scenario (200, 201, 400, 404, 500)

## Anti-Patterns

- Snapshot tests on complex components — fragile, documents nothing
- Testing implementation details (`wrapper.instance()`, `component.state()`)
- Excessive mocking — mocking everything empties test value
- `fireEvent` instead of `userEvent` — doesn't simulate real user behavior
- Tests without assertions — always-passing tests
- Manual `act()` — `userEvent` wraps in `act` automatically

## I/O Reference

|            |                                                                                    |
| ---------- | ---------------------------------------------------------------------------------- |
| Reads      | Active spec/test files, `@devflow/adapters/nextjs/ADAPTER.md`                      |
| Writes     | New or refactored Jest + RTL spec files                                            |
| Invoked by | `devflow-implement` for `**/*.test.tsx`, `**/*.test.ts`, `**/__tests__/**`         |
| Related    | `nextjs-components`, `nextjs-server`, `nextjs-forms`, `nextjs-state`               |
