# Next.js Testing — Code Patterns

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
