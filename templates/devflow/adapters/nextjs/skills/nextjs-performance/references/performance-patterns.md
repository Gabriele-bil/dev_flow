# Next.js Performance — Code Patterns

## 1) Image Optimization — `next/image`

### Local images (auto-sized)

```tsx
import Image from 'next/image'
import profilePic from './profile.png' // TypeScript knows width/height

export function Avatar() {
  return <Image src={profilePic} alt="Profile" placeholder="blur" />
}
```

### Remote images

```tsx
// next.config.ts — allowlist remote domains
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'images.example.com', pathname: '/uploads/**' },
    ],
  },
}
```

```tsx
<Image
  src="https://images.example.com/uploads/photo.jpg"
  alt="Photo"
  width={800}
  height={600}
  sizes="(max-width: 768px) 100vw, 50vw" // always set for remote images
/>
```

### LCP image — `priority`

Add `priority` to the largest image above the fold (hero, banner):

```tsx
<Image
  src={heroImage}
  alt="Hero"
  fill
  priority              // disables lazy loading, adds preload link
  sizes="100vw"
/>
```

### Fill mode (parent-relative)

```tsx
<div style={{ position: 'relative', width: '100%', height: '400px' }}>
  <Image
    src={photo}
    alt="Cover"
    fill
    style={{ objectFit: 'cover' }}
    sizes="(max-width: 768px) 100vw, 800px"
  />
</div>
```

### `sizes` attribute — always set for responsive images

```tsx
// without sizes → browser downloads at full viewport width
// with sizes → browser picks correct source for viewport
<Image
  src={thumbnail}
  alt="Product"
  width={400}
  height={300}
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 400px"
/>
```

### Blur placeholder

```tsx
// local images: automatic
<Image src={localPhoto} alt="..." placeholder="blur" />

// remote images: provide blurDataURL (base64 tiny image)
<Image
  src="https://..."
  alt="..."
  width={800}
  height={600}
  placeholder="blur"
  blurDataURL="data:image/png;base64,iVBORw0KGgoAAAANS..."
/>
```

## 2) Font Optimization — `next/font`

### Google Fonts

```tsx
// app/layout.tsx
import { Inter, Geist_Mono } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

const geistMono = Geist_Mono({
  subsets: ['latin'],
  variable: '--font-geist-mono',
  display: 'swap',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${geistMono.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

Tailwind CSS v4 integration:

```css
/* app/globals.css */
@theme {
  --font-sans: var(--font-inter);
  --font-mono: var(--font-geist-mono);
}
```

### Local Fonts

```tsx
import localFont from 'next/font/local'

const myFont = localFont({
  src: [
    { path: '../fonts/MyFont-Regular.woff2', weight: '400', style: 'normal' },
    { path: '../fonts/MyFont-Bold.woff2', weight: '700', style: 'normal' },
  ],
  variable: '--font-my',
  display: 'swap',
})
```

## 3) Script Loading — `next/script`

```tsx
import Script from 'next/script'
```

```tsx
// app/layout.tsx
import Script from 'next/script'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        {children}
        <Script src="https://cdn.example.com/widget.js" strategy="lazyOnload" />
      </body>
    </html>
  )
}
```

### Inline scripts — `id` obbligatorio

```tsx
<Script id="analytics-init" strategy="afterInteractive">
  {`window.dataLayer = window.dataLayer || []`}
</Script>
```

### Google Analytics — usa `@next/third-parties`

```bash
npm install @next/third-parties
```

```tsx
// app/layout.tsx
import { GoogleAnalytics } from '@next/third-parties/google'

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
      <GoogleAnalytics gaId="G-XXXXXXXXXX" />
    </html>
  )
}
```

## 4) Bundling Gotchas

### Server-incompatible packages

Some npm packages use browser APIs and cannot run in Server Components:

```ts
// next.config.ts
const nextConfig = {
  serverExternalPackages: ['some-native-package', 'canvas'],
}
```

### CSS imports — no `<link>` tags

```tsx
// ❌ — non funziona in Next.js
<link rel="stylesheet" href="/styles/vendor.css" />

// ✅ — importa come modulo
import '@/styles/vendor.css'
// oppure nel layout/page:
import 'some-package/dist/style.css'
```

### ESM/CommonJS conflicts

Se un pacchetto non viene bundlato correttamente:

```ts
// next.config.ts
const nextConfig = {
  transpilePackages: ['problematic-esm-package'],
}
```

### Bundle analysis

```bash
npm install @next/bundle-analyzer
```

```ts
// next.config.ts
import bundleAnalyzer from '@next/bundle-analyzer'

const withBundleAnalyzer = bundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
})

export default withBundleAnalyzer({ /* config */ })
```

```bash
ANALYZE=true npm run build
```
