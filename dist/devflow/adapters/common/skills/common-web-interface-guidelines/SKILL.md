---
name: common-web-interface-guidelines
description: Audit UI files against Vercel Web Interface Guidelines. Use when asked to "review UI", "check accessibility", "audit design", "review UX", or "check against best practices".
---

# Web Interface Guidelines

Audit files for compliance. Output terse, high signal. Group by file.

## Rules

### Accessibility

- Icon-only buttons: `aria-label` required
- Form controls: `<label>` or `aria-label` required
- Interactive elements: keyboard handlers required (`onKeyDown`/`onKeyUp`)
- Actions → `<button>`; navigation → `<a>`/`<Link>` (no `<div onClick>`)
- Images: `alt` required (or `alt=""` for decorative)
- Decorative icons: `aria-hidden="true"` required
- Async updates (toasts, validation): `aria-live="polite"` required
- Semantic HTML first (`<button>`, `<a>`, `<label>`, `<table>`), then ARIA
- Headings hierarchical `<h1>`–`<h6>`; include skip link for main content
- `scroll-margin-top` on heading anchors

### Focus States

- Interactive elements: visible focus via `focus-visible:ring-*` or equivalent
- Never `outline-none` / `outline: none` without focus replacement
- `:focus-visible` over `:focus` (avoid focus ring on click)
- Group focus: `:focus-within` for compound controls

### Forms

- Inputs: `autocomplete` + meaningful `name` required
- Correct `type` (`email`, `tel`, `url`, `number`) + `inputmode`
- Never block paste (`onPaste` + `preventDefault`)
- Labels clickable: `htmlFor` or wrapping control
- Disable spellcheck on emails, codes, usernames (`spellCheck={false}`)
- Checkboxes/radios: label + control share single hit target (no dead zones)
- Submit button stays enabled until request starts; spinner during request
- Errors inline next to fields; focus first error on submit
- Placeholders end with `…`, show example pattern
- `autocomplete="off"` on non-auth fields (avoid password manager triggers)
- Warn before navigation with unsaved changes (`beforeunload` or router guard)

### Animation

- Honor `prefers-reduced-motion` (reduced variant or disable)
- Animate `transform`/`opacity` only (compositor-friendly)
- Never `transition: all` — list properties explicitly
- Set correct `transform-origin`
- SVG: transforms on `<g>` wrapper with `transform-box: fill-box; transform-origin: center`
- Animations interruptible — respond to user input mid-animation

### Typography

- `…` not `...`
- Curly quotes `"` `"` not straight `"`
- Non-breaking spaces: `10&nbsp;MB`, `⌘&nbsp;K`, brand names
- Loading states end with `…`: `"Loading…"`, `"Saving…"`
- `font-variant-numeric: tabular-nums` for number columns/comparisons
- `text-wrap: balance` or `text-pretty` on headings (prevents widows)

### Content Handling

- Text containers handle long content: `truncate`, `line-clamp-*`, or `break-words`
- Flex children: `min-w-0` to allow text truncation
- Handle empty states — no broken UI for empty strings/arrays
- User-generated content: anticipate short, average, very long inputs

### Images

- `<img>`: explicit `width` + `height` required (prevents CLS)
- Below-fold: `loading="lazy"`
- Above-fold critical: `priority` or `fetchpriority="high"`

### Performance

- Lists >50 items: virtualize (`virtua`, `content-visibility: auto`)
- No layout reads in render (`getBoundingClientRect`, `offsetHeight`, `offsetWidth`, `scrollTop`)
- Batch DOM reads/writes; no interleaving
- Prefer uncontrolled inputs; controlled inputs must be cheap per keystroke
- `<link rel="preconnect">` for CDN/asset domains
- Critical fonts: `<link rel="preload" as="font">` + `font-display: swap`

### Navigation & State

- URL reflects state — filters, tabs, pagination, expanded panels in query params
- Links: `<a>`/`<Link>` (Cmd/Ctrl+click, middle-click support)
- Deep-link all stateful UI (if uses `useState`, consider URL sync via nuqs or similar)
- Destructive actions: confirmation modal or undo window — never immediate

### Touch & Interaction

- `touch-action: manipulation` (prevents double-tap zoom delay)
- `-webkit-tap-highlight-color` set intentionally
- `overscroll-behavior: contain` in modals/drawers/sheets
- During drag: disable text selection, `inert` on dragged elements
- `autoFocus` sparingly — desktop only, single primary input; avoid on mobile

### Safe Areas & Layout

- Full-bleed layouts: `env(safe-area-inset-*)` for notches
- Avoid unwanted scrollbars: `overflow-x-hidden` on containers, fix content overflow
- Flex/grid over JS measurement for layout

### Dark Mode & Theming

- `color-scheme: dark` on `<html>` for dark themes (fixes scrollbar, inputs)
- `<meta name="theme-color">` matches page background
- Native `<select>`: explicit `background-color` + `color` (Windows dark mode)

### Locale & i18n

- Dates/times: `Intl.DateTimeFormat` — no hardcoded formats
- Numbers/currency: `Intl.NumberFormat` — no hardcoded formats
- Detect language via `Accept-Language` / `navigator.languages`, not IP
- Brand names, code tokens, identifiers: `translate="no"` (prevents garbled auto-translation)

### Hydration Safety

- Inputs with `value`: `onChange` required (or `defaultValue` for uncontrolled)
- Date/time rendering: guard against hydration mismatch (server vs client)
- `suppressHydrationWarning`: only where truly needed

### Hover & Interactive States

- Buttons/links: `hover:` state required (visual feedback)
- Interactive states increase contrast: hover/active/focus more prominent than rest

### Content & Copy

- Active voice: "Install CLI" not "CLI will be installed"
- Title Case for headings/buttons (Chicago style)
- Numerals for counts: "8 deployments" not "eight"
- Specific button labels: "Save API Key" not "Continue"
- Error messages include fix/next step, not just problem
- Second person; no first person
- `&` over "and" where space-constrained

### Anti-patterns (flag these)

- `user-scalable=no` or `maximum-scale=1` disabling zoom
- `onPaste` + `preventDefault`
- `transition: all`
- `outline-none` without `focus-visible` replacement
- Inline `onClick` navigation without `<a>`
- `<div>`/`<span>` with click handlers (use `<button>`)
- Images without dimensions
- Large arrays `.map()` without virtualization
- Form inputs without labels
- Icon buttons without `aria-label`
- Hardcoded date/number formats (use `Intl.*`)
- `autoFocus` without clear justification

## Output Format

Group by file. `file:line` format (VS Code clickable). Terse.

## I/O Reference

| | |
| --- | --- |
| Reads | UI source files passed by the user |
| Writes | Nothing — audit output only |
| Next step | Apply fixes, then re-run if needed |
