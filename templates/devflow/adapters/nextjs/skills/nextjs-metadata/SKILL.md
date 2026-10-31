---
name: nextjs-metadata
description: Metadata API, SEO, OG images, file-based metadata (robots, sitemap, icons), viewport. Load when touching generateMetadata, metadata exports, opengraph-image, robots.ts, or sitemap.ts.
---

# Skill: Next.js Metadata

## Purpose

Project rules for SEO metadata, OG images and file-based metadata in App Router. Examples: `references/metadata-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Page data fetching itself → `nextjs-server`
- Image/font performance → `nextjs-performance`

## Rules

- Metadata only through the Metadata API (`metadata` export or `generateMetadata`) — no hand-written `<meta>` / `<title>` in components. Server Components only.
- Root `app/layout.tsx`: `metadataBase`, `title: { template: '%s | <App>', default: '<App>' }`, default `description`, `openGraph.siteName`.
- Pages set `title` + `description`; data-driven pages use `generateMetadata({ params })` with `await params`.
- Data shared by `generateMetadata` and page → one `lib/` function wrapped in `React.cache()` (or `'use cache'`), called from both — no double query.
- Viewport / `themeColor` → separate `viewport` / `generateViewport` export, never inside `metadata`.
- OG images: file-based `opengraph-image.tsx` with `ImageResponse` from `next/og` next to the page; static `opengraph-image.png` when content does not vary. Route-based `app/api/og/route.tsx` only for query-driven images.
- `robots.ts` + `sitemap.ts` at `app/` root, typed with `MetadataRoute`. >50k URLs → `generateSitemaps`.
- Icons: `app/icon.svg`, `app/apple-icon.png`, `app/favicon.ico` — files, no code.
- Private / auth routes: `robots: { index: false }` in `(app)/layout.tsx`.

## Review checklist

- [ ] No manual `<meta>` tags
- [ ] `title.template` + `metadataBase` in root layout
- [ ] `generateMetadata` reuses cached data function
- [ ] Viewport exported separately
- [ ] `robots.ts` / `sitemap.ts` present for public sites

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`generateMetadata`, `metadata` export, `opengraph-image.*`, `twitter-image.*`, `robots.ts`, `sitemap.ts`, `icon.*`) |
| Reads | `references/metadata-patterns.md` |
| Writes | Metadata exports, OG image routes, `robots.ts`, `sitemap.ts` |
| Related | `nextjs-server`, `nextjs-architecture` |
