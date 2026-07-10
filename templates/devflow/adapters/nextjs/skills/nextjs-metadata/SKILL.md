---
name: nextjs-metadata
description: Metadata API, SEO, OG images, file-based metadata. Load when touching generateMetadata, opengraph-image, or head files.
---

# Skill: Next.js Metadata

Use when implementing SEO metadata, Open Graph images, or file-based metadata conventions.

Full code examples: `references/metadata-patterns.md`.

## 1) Static Metadata

Export `metadata` object from `page.tsx` or `layout.tsx` — `title`, `description`, `openGraph`, `twitter`. Only Server Components can export `metadata`. Full code → `references/metadata-patterns.md`.

## 2) Dynamic Metadata — `generateMetadata`

Use for pages where title/description depend on fetched data. In Next.js 15+, `params` is async. Fetch inside `generateMetadata` is automatically deduped with the same fetch in `page.tsx` if using the same cache key; use React's `cache()` to dedup non-fetch data functions. Full code → `references/metadata-patterns.md`.

## 3) OG Image Generation — `next/og`

Two approaches: **file-based** (`opengraph-image.tsx` alongside `page.tsx`, Next.js auto-generates route + meta tag) for simple cases, or **route-based** (`app/api/og/route.tsx`) for more control (e.g. query-param driven images). Both use `ImageResponse` from `next/og`. Full code → `references/metadata-patterns.md`.

## 4) Metadata Templates — `title.template`

Set `title: { template: '%s | My App', default: 'My App' }` in root layout to avoid repeating site name on every page. Full code → `references/metadata-patterns.md`.

## 5) File-Based Metadata Conventions

Place these files in `app/` (or route folders) — no code needed:

| File | Output |
| --- | --- |
| `favicon.ico` | `<link rel="icon">` |
| `icon.png` / `icon.svg` | `<link rel="icon">` |
| `apple-icon.png` | `<link rel="apple-touch-icon">` |
| `opengraph-image.png` | `<meta property="og:image">` |
| `twitter-image.png` | `<meta name="twitter:image">` |
| `robots.txt` | `/robots.txt` |
| `sitemap.xml` | `/sitemap.xml` |

Dynamic versions use `.ts` extension (`robots.ts`, `sitemap.ts`). Full code → `references/metadata-patterns.md`.

## 6) Viewport — `generateViewport`

Separate viewport from metadata for better tree-shaking. Export `generateViewport` (dynamic, e.g. based on `params`) or `viewport` (static). Full code → `references/metadata-patterns.md`.

## 7) Sitemap multipla — `generateSitemaps`

Per siti con molte pagine (>50k URL), dividi in più sitemap con `generateSitemaps` — Next.js genera `/sitemap/0.xml`, `/sitemap/1.xml`, ecc. Full code → `references/metadata-patterns.md`.

## 8) OG Images multiple — `generateImageMetadata`

Genera più varianti di OG image per una stessa route (es. dark/light, locale). Full code → `references/metadata-patterns.md`.

## 9) Anti-Patterns

- Do NOT manually add `<meta>` tags in components — use the Metadata API.
- Do NOT fetch the same data twice in `generateMetadata` and `page.tsx` — use `cache()` for dedup.
- Do NOT put `metadata` export in Client Components — only Server Components export metadata.
- Do NOT forget `title.template` in root layout — causes repeated site name in every page title.
- Do NOT mix `viewport` inside `metadata` export — usa `generateViewport` separato.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when touching `generateMetadata`, `generateViewport`, `generateSitemaps`, `generateImageMetadata`, `opengraph-image`, `robots.ts`, `sitemap.ts`, or metadata-related config |
| Related | `nextjs-server`, `nextjs-architecture` |
