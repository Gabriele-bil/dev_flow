# Next.js Architecture — project patterns

Loaded on demand from `../SKILL.md`.

## Project tree

```text
app/
├── (marketing)/          # public: layout.tsx (nav, footer), page.tsx "/"
├── (app)/                # authenticated
│   ├── layout.tsx        # shell + auth check
│   └── <feature>/
│       ├── page.tsx
│       ├── loading.tsx
│       ├── error.tsx
│       ├── actions.ts    # Server Actions for this route
│       ├── _components/
│       └── _lib/         # schema.ts, queries.ts
├── api/<resource>/route.ts   # external consumers only
├── providers.tsx
├── globals.css
└── layout.tsx            # html, body, fonts, <Providers>
components/ui/            # shadcn primitives
components/<feature>/     # shared across routes
lib/<domain>/             # data access, utils — no React
proxy.ts                  # project root, Node runtime
```

## Providers

```tsx
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      {children}
    </ThemeProvider>
  )
}
```

Root layout: `<html lang="en" suppressHydrationWarning>` (next-themes sets class before hydration), `<body><Providers>{children}</Providers></body>`.

## Proxy

```ts
// proxy.ts
import { NextResponse, type NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  if (!request.cookies.has('session')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const config = { matcher: ['/dashboard/:path*'] }
```

Optimistic redirect only — Server Actions and data functions still verify the session. Never add `runtime` config to `proxy.ts`.
