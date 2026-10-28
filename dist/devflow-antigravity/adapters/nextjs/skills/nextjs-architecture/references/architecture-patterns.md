# Next.js Architecture — Code Patterns

## 4) Recommended App Structure

```text
app/
├── (marketing)/               # public pages, no auth required
│   ├── layout.tsx             # marketing layout (nav, footer)
│   ├── page.tsx               # home page "/"
│   ├── about/
│   │   └── page.tsx
│   └── blog/
│       ├── page.tsx           # blog index
│       └── [slug]/
│           └── page.tsx       # blog post
├── (app)/                     # authenticated area
│   ├── layout.tsx             # app layout (sidebar, header) — auth check here
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── loading.tsx        # shown while dashboard data streams
│   │   ├── error.tsx          # catches dashboard errors
│   │   └── _components/       # dashboard-only components (not routable)
│   ├── settings/
│   │   ├── page.tsx
│   │   └── _components/
│   └── [feature]/
│       ├── page.tsx
│       ├── loading.tsx
│       ├── error.tsx
│       ├── _components/
│       └── actions.ts         # Server Actions for this route
├── api/                       # API Routes
│   └── [resource]/
│       └── route.ts
├── globals.css
└── layout.tsx                 # Root layout — html, body, global providers ONLY

lib/                           # Shared utilities — no UI, no React
├── utils.ts
├── validations.ts
└── [domain]/
    └── *.ts

components/                    # Shared UI components
├── ui/                        # shadcn/ui primitives (Button, Input, etc.)
└── [feature]/                 # Feature-specific shared components

proxy.ts                       # At project root — NOT inside app/ (Next.js 16+)
```

## 5) Server/Client Boundary Rules

```tsx
// providers.tsx — wrap all context providers here
'use client'
import { ThemeProvider } from 'next-themes'
import { SessionProvider } from 'next-auth/react'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SessionProvider>
      <ThemeProvider attribute="class" defaultTheme="system">
        {children}
      </ThemeProvider>
    </SessionProvider>
  )
}

// app/layout.tsx — stays Server Component
import { Providers } from './_components/providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

## 7) Middleware / Proxy

```ts
// middleware.ts (Next.js 14-15)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('session')?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/app/:path*', '/dashboard/:path*'],
}
```

```ts
// proxy.ts (Next.js 16+)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const token = request.cookies.get('session')?.value
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const proxyConfig = {
  matcher: ['/app/:path*', '/dashboard/:path*'],
}
```

## 9) Parallel Routes and Intercepting Routes

### Parallel Routes — `@name` slots

Render multiple pages simultaneously inside the same layout (e.g. modal overlay on background page):

```text
app/
  @modal/                    # parallel slot
    (.)product/[id]/         # intercepting route — intercepts /product/[id]
      page.tsx               # modal content
  product/
    [id]/
      page.tsx               # full page (direct navigation / refresh)
  layout.tsx                 # receives { children, modal }
  default.tsx                # returns null — fallback slot when @modal is inactive
```

```tsx
// app/layout.tsx
export default function RootLayout({
  children,
  modal,
}: {
  children: React.ReactNode
  modal: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {children}
        {modal}
      </body>
    </html>
  )
}
```

```tsx
// app/default.tsx — required to prevent 404 on hard refresh
export default function Default() {
  return null
}
```

```tsx
// app/@modal/(.)product/[id]/page.tsx — modal client component
'use client'
import { use } from 'react'
import { useRouter } from 'next/navigation'

export default function ProductModal({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params) // React 19 use() to unwrap async params in Client Component
  const router = useRouter()

  return (
    <dialog open className="backdrop:bg-black/50 p-6 rounded-lg">
      <button onClick={() => router.back()} className="text-sm font-semibold">Close</button>
      <p>Product ID: {id}</p>
    </dialog>
  )
}
```

**Rules:**

- `default.tsx` required in every parallel slot — prevents 404 on hard refresh.
- Close modal via `router.back()`, not `router.push('/')`.
- Intercepting conventions: `(.)` = same level, `(..)` = one level up, `(...)` = root `app/`.

## 2) Route Segment Files

Each route folder can contain these reserved filenames:

| File | Purpose |
| --- | --- |
| `page.tsx` | Route leaf — makes URL publicly accessible |
| `layout.tsx` | Persistent wrapper — wraps page and children, does NOT re-mount on navigation |
| `loading.tsx` | Automatic Suspense boundary — shows while page/children stream |
| `error.tsx` | Error boundary with `reset` prop — catches runtime errors in subtree |
| `global-error.tsx` | Error boundary for root layout — must include `<html>` and `<body>` tags |
| `not-found.tsx` | Renders when `notFound()` is called within subtree |
| `template.tsx` | Like layout but re-mounts on every navigation — use when fresh state per nav is required |
| `default.tsx` | Fallback for parallel route slots — return `null` when slot is inactive |
| `route.ts` | API Route handler — no UI, named exports only (`GET`, `POST`, etc.) |
| `opengraph-image.tsx` | Auto-generated OG image for route — runs on Edge runtime |
| `twitter-image.tsx` | Auto-generated Twitter card image — runs on Edge runtime |

Rules:

- `layout.tsx` receives `children: React.ReactNode` — never fetch data that changes per-page inside root layout.
- `error.tsx` MUST be a Client Component (`'use client'`). Receives `error` and `reset` props.
- `global-error.tsx` MUST be a Client Component AND include `<html><body>` tags — replaces root layout on error.
- `loading.tsx` wraps `page.tsx` in `<Suspense>` automatically — no manual wrapping needed.
- `template.tsx` use case: tabs with per-tab animation, forms that must reset, auth-check per navigation.

## 3) Route Groups and Private Folders

**Route groups** — parentheses: `(group-name)/`

- Organize routes without adding URL segment.
- Each group can have its own `layout.tsx`.
- Use to split authenticated vs public layout.

**Private folders** — `_` prefix: `_folder-name/`

- Excluded from routing system entirely.
- Use for components, hooks, lib co-located with a route but not routes themselves.

## 7) Middleware / Proxy

File at **project root** (sibling to `app/`, `lib/`, `components/`). Never inside `app/`.

Next.js 16+ renamed `middleware.ts` → `proxy.ts` (codemod: `npx @next/codemod@latest upgrade`):

| Version | File | Export | Matcher config |
| --- | --- | --- | --- |
| 14–15 | `middleware.ts` | `middleware()` | `config` |
| 16+ | `proxy.ts` | `proxy()` | `proxyConfig` |

Full code for both versions → `references/architecture-patterns.md`.

## 8) Naming Conventions

| Target | Convention | Example |
| --- | --- | --- |
| Folders / files | kebab-case | `user-profile/`, `user-card.tsx` |
| React components | PascalCase (function name) | `export function UserCard()` |
| Utility functions | camelCase | `formatDate()`, `parseSlug()` |
| Server Actions files | `actions.ts` | `app/dashboard/actions.ts` |
| API route handlers | `route.ts` | `app/api/users/route.ts` |
| Private folders | `_` prefix | `_components/`, `_lib/`, `_hooks/` |
| Route groups | `()` wrapping | `(marketing)/`, `(app)/` |
| Dynamic segments | `[]` wrapping | `[slug]/`, `[id]/` |
| Catch-all segments | `[...]` wrapping | `[...slug]/` |
