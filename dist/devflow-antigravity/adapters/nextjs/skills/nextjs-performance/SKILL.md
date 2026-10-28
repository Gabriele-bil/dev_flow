---
name: nextjs-performance
description: next/image, next/font, next/script, bundling gotchas. Load when touching img tags, font imports, script tags, or next.config.ts.
---

# Skill: Next.js Performance

Use when optimizing images, fonts, third-party scripts, or resolving bundling issues.

Full code examples: `references/performance-patterns.md`.

## 1) Image Optimization — `next/image`

**Never use `<img>` directly.** Always use `next/image` — provides automatic format conversion (WebP/AVIF), lazy loading, size optimization, and LCP tracking.

- Local images are auto-sized from import; remote images require `width`/`height` and a `remotePatterns` allowlist in `next.config.ts`.
- Add `priority` to the largest above-the-fold image (hero, banner) — disables lazy loading, adds preload link.
- Use `fill` + a positioned parent for cover-style images; always set `sizes` on responsive images (missing `sizes` causes oversized downloads).
- Use `placeholder="blur"` — automatic for local images, needs `blurDataURL` for remote images.

Full code → `references/performance-patterns.md`.

## 2) Font Optimization — `next/font`

Fonts are self-hosted automatically — zero layout shift, no external requests.

- Google Fonts: `next/font/google`; Local fonts: `next/font/local`.
- Always use `variable` mode to integrate with Tailwind/CSS variables.
- Specify `subsets` to preload only needed character sets — reduces font file size.
- Declare fonts in `layout.tsx` — not in individual components.

Full code (incl. Tailwind v4 integration) → `references/performance-patterns.md`.

## 3) Script Loading — `next/script`

**Never use `<script>` tags directly** in Next.js pages/layouts.

| Strategy | When JS loads | Use for |
| --- | --- | --- |
| `beforeInteractive` | Before page hydration | Critical polyfills (rare) |
| `afterInteractive` (default) | After page hydration | Tag managers, analytics |
| `lazyOnload` | Browser idle | Low-priority third-party widgets |
| `worker` | Web Worker (experimental) | CPU-intensive scripts |

Inline scripts require an `id`. For Google Analytics use `@next/third-parties` instead of hand-rolled scripts. Full code → `references/performance-patterns.md`.

## 4) Bundling Gotchas

- Packages using browser APIs that break Server Components → add to `serverExternalPackages` in `next.config.ts`.
- No `<link rel="stylesheet">` tags — import CSS as a module (`import '@/styles/vendor.css'`).
- Packages not bundled correctly (ESM/CommonJS conflicts) → add to `transpilePackages`.
- Use `@next/bundle-analyzer` (`ANALYZE=true npm run build`) to inspect bundle composition.

Full code → `references/performance-patterns.md`.

## 5) Anti-Patterns

- No `<img>` — always `next/image`.
- No `<link rel="preload">` for fonts — `next/font` handles it.
- No `<script>` tags in components — use `next/script`.
- No `strategy="beforeInteractive"` unless truly critical — blocks hydration.
- No font import in individual components — declare once in root `layout.tsx`.
- No remote image domains without `remotePatterns` — breaks at runtime.
- No missing `sizes` on responsive images — causes oversized downloads.

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` when touching `<img>`, font imports, `<script>` tags, `next.config.ts` images/font/script config |
| Related | `nextjs-architecture`, `nextjs-ui`, `nextjs-metadata` |
