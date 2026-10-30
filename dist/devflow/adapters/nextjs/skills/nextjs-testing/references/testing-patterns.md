# Next.js Testing — project patterns

Loaded on demand from `../SKILL.md`. Check current Next.js testing docs with Context7 before changing Jest config.

## Jest config

```ts
// jest.config.ts
import type { Config } from 'jest'
import nextJest from 'next/jest.js'

const createJestConfig = nextJest({ dir: './' })

const config: Config = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/$1' },
  testPathIgnorePatterns: ['<rootDir>/e2e/'],
  collectCoverageFrom: [
    '{app,components,lib}/**/*.{ts,tsx}',
    '!**/*.d.ts',
    '!**/*.stories.tsx',
    '!app/layout.tsx',
  ],
  coverageThreshold: { global: { statements: 80, branches: 80, functions: 80, lines: 80 } },
}

export default createJestConfig(config)
```

`jest.setup.ts`: `import '@testing-library/jest-dom'`.

## Route Handler — invalid body is 400

```ts
import { NextRequest } from 'next/server'
import { POST } from './route'

it('returns 400 for invalid body', async () => {
  const req = new NextRequest('http://localhost/api/products', {
    method: 'POST',
    body: JSON.stringify({ name: '' }),
  })
  const res = await POST(req)
  expect(res.status).toBe(400)
})
```

Dynamic segment handler: `await GET(req, { params: Promise.resolve({ id: '123' }) })`.

## Server Action with cache calls mocked

```ts
jest.mock('next/cache', () => ({ updateTag: jest.fn(), revalidateTag: jest.fn(), refresh: jest.fn() }))

it('rejects invalid input', async () => {
  const fd = new FormData()
  fd.set('name', '')
  const result = await createItem(null, fd)
  expect(result).toMatchObject({ success: false })
})
```

## Form — user flow

```tsx
it('shows validation error on empty submit', async () => {
  const user = userEvent.setup()
  render(<ProfileForm initial={{ name: '', email: '' }} />)
  await user.click(screen.getByRole('button', { name: /save/i }))
  expect(await screen.findByText(/name required/i)).toBeInTheDocument()
})
```

## Async Server Component — Playwright

```ts
// e2e/dashboard.spec.ts
import { test, expect } from '@playwright/test'

test('dashboard shows metrics', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
})
```
