---
name: common-web-interface-guidelines
description: Audit UI files against Vercel Web Interface Guidelines. Use when asked to "review UI", "check accessibility", "audit design", "review UX", or "check against best practices".
---

# Web Interface Guidelines

Framework-neutral (Angular templates, React/Next.js JSX, plain HTML). Rules name HTML/CSS/ARIA; map to framework syntax (`for` ↔ `htmlFor`, `(click)` ↔ `onClick`). Semantic HTML first, ARIA second (WAI-ARIA "first rule of ARIA").

## Purpose

Audit web UI files for accessibility, forms, focus, motion, content. Output terse findings, grouped by file, `file:line`.

## When NOT to Use

- File matches no row of the active adapter's `steps/implement.md` → skill load decision matrix that names this skill (beautify steps may load it explicitly)
- Non-web UI (Flutter widgets) — use the Flutter adapter's skills
- Visual redesign / brand decisions — out of scope; audit only

## Rules

### Accessibility

- Actions → `<button type="button">`; navigation → `<a href>` (or router link). Never click handler on `<div>`/`<span>`
- Native `<button>`/`<a>`: no key handler needed — `click` already fires on Enter (and Space for buttons)
- Custom widget only when no native element fits: matching `role`, `tabindex="0"`, Enter/Space (or APG keys for the pattern) keydown handling, ARIA state (`aria-expanded`, `aria-selected`, …)
- Icon-only buttons: accessible name (`aria-label` or visually hidden text); decorative icons `aria-hidden="true"`
- Images: `alt` (`alt=""` for decorative)
- Form controls: visible `<label>` (`for`/wrapping); `aria-label` only when no visible label fits
- Async updates (toasts, inline validation): `aria-live="polite"` region present before update
- Headings `<h1>`–`<h6>` in order; skip link to main content; `scroll-margin-top` on anchor targets
- Never disable zoom (`user-scalable=no`, `maximum-scale=1`)

### Focus

- Visible focus on every interactive element via `:focus-visible` (Tailwind `focus-visible:` variant)
- Never `outline: none` / `outline-none` without replacement style
- `:focus-within` for compound controls
- Dialogs: focus moves in on open, returns to trigger on close

### Forms

- `autocomplete` with specific token on personal/auth fields (`name`, `email`, `tel`, `street-address`, `username`, `current-password`, `new-password`, `one-time-code`) + meaningful `name` (WCAG 1.3.5)
- `autocomplete="off"` only where browser autofill is wrong: search boxes with own suggestions, custom comboboxes, non-personal data. Never on login/personal fields — browsers ignore it there anyway
- Correct `type` (`email`, `tel`, `url`, `number`) + `inputmode`
- Never block paste
- `spellcheck="false"` on emails, codes, usernames
- Checkbox/radio: label + control one hit target
- Submit enabled until request starts; busy indicator during request
- Errors inline next to field, linked via `aria-describedby`; focus first invalid field on submit
- Placeholder = example value ending `…`, never replaces label
- Warn before leaving with unsaved changes (router guard / `beforeunload`)

### Animation

- Honor `prefers-reduced-motion`
- Animate `transform`/`opacity` only; never `transition: all`
- Correct `transform-origin`; SVG: transform on `<g>` with `transform-box: fill-box`
- Interruptible by user input

Remaining groups (Typography, Content, Images, Performance, Navigation & State, Touch, Layout, Theming, i18n, SSR/Hydration, Copy): [references/guidelines-detail.md](references/guidelines-detail.md) — part of every full audit; read before reporting.

## Output Format

Group by file. `file:line — rule — fix`. Terse. No praise, no summary of passing rules.

## I/O Reference

| | |
| --- | --- |
| Reads | UI source files (templates, components, CSS) passed by the user or the invoking step |
| Writes | Nothing — audit output only |
| Invoked by | Adapter `steps/implement.md` matrix rows; adapter `steps/beautify.md` |
| Next step | Apply fixes, then re-run if needed |
