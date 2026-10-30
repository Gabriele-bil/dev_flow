# Web Interface Guidelines — reference detail

Loaded on demand from `../SKILL.md`. Framework-neutral; map to Angular/JSX syntax.

## Typography

- `…` not `...`; loading labels end `…` (`Loading…`)
- Curly quotes; `&nbsp;` in `10&nbsp;MB`, `⌘&nbsp;K`
- `font-variant-numeric: tabular-nums` on number columns
- `text-wrap: balance` (headings) / `pretty` (body)

## Content

- Long text: truncate / `line-clamp` / `overflow-wrap: anywhere`; flex children `min-width: 0`
- Empty states for empty strings/lists; design for short, average, very long input

## Images

- Explicit `width` + `height` (prevents CLS)
- Below fold: `loading="lazy"`; LCP image: not lazy, `fetchpriority="high"` (framework image component: its priority/preload option — check current docs with Context7)

## Performance

- Lists >50 items: virtual scroll or `content-visibility: auto`
- No layout reads (`getBoundingClientRect`, `offsetHeight`, `scrollTop`) during render; batch reads before writes
- Per-keystroke work cheap
- `<link rel="preconnect">` for asset domains; critical fonts preloaded + `font-display: swap`

## Navigation & State

- URL holds shareable UI state: filters, tabs, pagination, open panels (query params)
- Links are `<a href>` so Cmd/Ctrl/middle-click work
- Destructive actions: confirmation or undo window, never immediate

## Touch

- `touch-action: manipulation`; `-webkit-tap-highlight-color` set deliberately
- `overscroll-behavior: contain` in modals/drawers/sheets
- During drag: disable text selection
- `autofocus` only for single primary input on desktop; never on mobile

## Layout

- Full-bleed: `env(safe-area-inset-*)`
- Fix overflow at source; no blanket `overflow-x: hidden` hiding bugs
- CSS flex/grid over JS measurement

## Theming

- `color-scheme` on `<html>` matches theme (scrollbars, native inputs)
- `<meta name="theme-color">` matches background
- Native `<select>`: explicit `background-color` + `color`

## i18n

- Dates/numbers/currency: `Intl.DateTimeFormat` / `Intl.NumberFormat` or framework pipe built on it — no hardcoded formats
- Language from `Accept-Language` / `navigator.languages`, not IP
- `translate="no"` on brand names, code, identifiers

## SSR / Hydration (Next.js, Angular SSR)

- Server and client render identical markup: no `Date.now()`, `Math.random()`, locale/timezone or `window` reads in first render
- Suppress hydration warnings only on the single node that must differ

## Hover & States

- Hover, active, focus states on every interactive element; each more prominent than rest
- Disabled: `disabled` attribute (not only styling)

## Copy

- Active voice, second person; specific labels ("Save API key", not "Continue")
- Numerals for counts ("8 deployments")
- Error messages state fix / next step
- Heading/button casing: one convention per product, applied everywhere
