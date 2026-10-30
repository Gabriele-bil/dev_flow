---
name: nextjs-performance
description: next/image (preload, sizes, remotePatterns), next/font, next/script, bundling and bundle analysis. Load when touching img tags, next/image, font imports, script tags, or next.config.ts.
---

# Skill: Next.js Performance

## Purpose

Project rules for images, fonts, third-party scripts and bundle weight. Examples: `references/performance-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Data caching / streaming → `nextjs-server`
- OG images and metadata → `nextjs-metadata`

## Images — `next/image`

- `next/image` only; raw `<img>` only for `data:`/SVG inline cases with a comment why.
- LCP image (hero, banner): `preload` prop — `priority` is deprecated in Next 16; never combine `preload` with `loading="lazy"`. Keep LCP image outside `<Suspense>`.
- Remote images: `width` + `height` (or `fill`) and an `images.remotePatterns` entry in `next.config.ts`.
- `fill` → positioned parent + `sizes`. Every responsive image sets `sizes`.
- `placeholder="blur"`: automatic for static imports; remote needs `blurDataURL`.

## Fonts — `next/font`

- Declare once in root `layout.tsx` (`next/font/google` or `next/font/local`), `subsets` set, `variable: '--font-<name>'`.
- Hook into Tailwind with `@theme inline { --font-sans: var(--font-<name>); }` (see `nextjs-ui`).
- No `<link>` to font CDNs, no `<link rel="preload">` for fonts.

## Scripts — `next/script`

- No raw `<script>`. Default `afterInteractive`; widgets `lazyOnload`; `beforeInteractive` only for critical polyfills.
- Inline script needs `id`.
- Google Analytics / Tag Manager → `@next/third-parties/google`.

## Bundling

- `'use client'` at leaves; heavy below-fold client widgets → `next/dynamic`.
- Server-only native packages → `serverExternalPackages`; ESM/CJS issues in workspace packages → `transpilePackages`.
- CSS via `import`, never `<link rel="stylesheet">`.
- Inspect weight: `pnpm exec next analyze` (Turbopack analyzer, default bundler). `@next/bundle-analyzer` works with webpack builds only. Check current docs with Context7 for analyzer flags.

## Anti-Patterns

- `priority` on `next/image` (deprecated — use `preload` instead).
- Missing `sizes` on responsive/`fill` images → oversized downloads.
- Font import in individual components.
- `beforeInteractive` for analytics.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`<img>`, `next/image`, `next/font`, `next/script`, `<script>`, `next.config.ts`) |
| Reads | `references/performance-patterns.md` |
| Writes | Image/font/script usage, `next.config.ts` |
| Related | `nextjs-architecture`, `nextjs-ui`, `nextjs-metadata` |
