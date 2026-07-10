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

middleware.ts                  # At project root — NOT inside app/
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

## 9) Parallel Routes e Intercepting Routes

### Parallel Routes — slot `@name`

Rendono più pagine nello stesso layout simultaneamente (es. modale su sfondo):

```text
app/
  @modal/                    # slot parallelo
    (.)product/[id]/         # intercepting route — cattura /product/[id]
      page.tsx               # contenuto modale
  product/
    [id]/
      page.tsx               # pagina completa (navigazione diretta / refresh)
  layout.tsx                 # riceve { children, modal }
  default.tsx                # ritorna null — slot fallback quando @modal inattivo
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
// app/default.tsx — obbligatorio per evitare 404 al refresh
export default function Default() {
  return null
}
```

```tsx
// app/@modal/(.)product/[id]/page.tsx — modale
'use client'
import { useRouter } from 'next/navigation'

export default async function ProductModal({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)

  return (
    <dialog open>
      <button onClick={() => useRouter().back()}>Chiudi</button>
      <ProductDetail product={product} />
    </dialog>
  )
}
```

**Regole:**

- `default.tsx` obbligatorio in ogni slot parallelo — evita 404 al refresh diretto.
- Chiudi il modale con `router.back()`, non `router.push('/')`.
- Notazione intercepting: `(.)` = stesso livello, `(..)` = un livello su, `(...)` = root.
