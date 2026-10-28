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

Remaining rule groups (Typography, Content Handling, Images, Performance, Navigation & State, Touch & Interaction, Safe Areas & Layout, Dark Mode & Theming, Locale & i18n, Hydration Safety, Hover & Interactive States, Content & Copy): [references/guidelines-detail.md](references/guidelines-detail.md) — part of every full audit; read before reporting.

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
