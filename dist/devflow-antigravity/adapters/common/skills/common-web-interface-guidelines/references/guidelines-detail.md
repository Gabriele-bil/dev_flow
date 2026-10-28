# Web Interface Guidelines — reference detail

Loaded on demand from `../SKILL.md`.

## Typography

- `…` not `...`
- Curly quotes `"` `"` not straight `"`
- Non-breaking spaces: `10&nbsp;MB`, `⌘&nbsp;K`, brand names
- Loading states end with `…`: `"Loading…"`, `"Saving…"`
- `font-variant-numeric: tabular-nums` for number columns/comparisons
- `text-wrap: balance` or `text-pretty` on headings (prevents widows)

## Content Handling

- Text containers handle long content: `truncate`, `line-clamp-*`, or `break-words`
- Flex children: `min-w-0` to allow text truncation
- Handle empty states — no broken UI for empty strings/arrays
- User-generated content: anticipate short, average, very long inputs

## Images

- `<img>`: explicit `width` + `height` required (prevents CLS)
- Below-fold: `loading="lazy"`
- Above-fold critical: `priority` or `fetchpriority="high"`

## Performance

- Lists >50 items: virtualize (`virtua`, `content-visibility: auto`)
- No layout reads in render (`getBoundingClientRect`, `offsetHeight`, `offsetWidth`, `scrollTop`)
- Batch DOM reads/writes; no interleaving
- Prefer uncontrolled inputs; controlled inputs must be cheap per keystroke
- `<link rel="preconnect">` for CDN/asset domains
- Critical fonts: `<link rel="preload" as="font">` + `font-display: swap`

## Navigation & State

- URL reflects state — filters, tabs, pagination, expanded panels in query params
- Links: `<a>`/`<Link>` (Cmd/Ctrl+click, middle-click support)
- Deep-link all stateful UI (if uses `useState`, sync URL via nuqs or similar)
- Destructive actions: confirmation modal or undo window — never immediate

## Touch & Interaction

- `touch-action: manipulation` (prevents double-tap zoom delay)
- `-webkit-tap-highlight-color` set intentionally
- `overscroll-behavior: contain` in modals/drawers/sheets
- During drag: disable text selection, `inert` on dragged elements
- `autoFocus` sparingly — desktop only, single primary input; avoid on mobile

## Safe Areas & Layout

- Full-bleed layouts: `env(safe-area-inset-*)` for notches
- Avoid unwanted scrollbars: `overflow-x-hidden` on containers, fix content overflow
- Flex/grid over JS measurement for layout

## Dark Mode & Theming

- `color-scheme: dark` on `<html>` for dark themes (fixes scrollbar, inputs)
- `<meta name="theme-color">` matches page background
- Native `<select>`: explicit `background-color` + `color` (Windows dark mode)

## Locale & i18n

- Dates/times: `Intl.DateTimeFormat` — no hardcoded formats
- Numbers/currency: `Intl.NumberFormat` — no hardcoded formats
- Detect language via `Accept-Language` / `navigator.languages`, not IP
- Brand names, code tokens, identifiers: `translate="no"` (prevents garbled auto-translation)

## Hydration Safety

- Inputs with `value`: `onChange` required (or `defaultValue` for uncontrolled)
- Date/time rendering: guard against hydration mismatch (server vs client)
- `suppressHydrationWarning`: only where truly needed

## Hover & Interactive States

- Buttons/links: `hover:` state required (visual feedback)
- Interactive states increase contrast: hover/active/focus more prominent than rest

## Content & Copy

- Active voice: "Install CLI" not "CLI will be installed"
- Title Case for headings/buttons (Chicago style)
- Numerals for counts: "8 deployments" not "eight"
- Specific button labels: "Save API Key" not "Continue"
- Error messages include fix/next step, not only problem
- Second person; no first person
- `&` over "and" where space-constrained
