# Accessibility Checklist

Stack-agnostic. WCAG 2.1 AA baseline.
Stack-specific patterns in active `ADAPTER.md` → **Beautify: accessibility**.

## Keyboard / Focus (Web)

- [ ] All interactive elements focusable via Tab
- [ ] Focus order follows visual/logical order
- [ ] Focus visible (outline/ring on focused element)
- [ ] Custom widgets: Enter activates, Escape closes
- [ ] No keyboard traps — user can always Tab away
- [ ] Modals trap focus while open, restore on close
- [ ] Skip-to-content link at page top

## Screen Readers

- [ ] Images: `alt` text or `alt=""` for decorative
- [ ] Form inputs: associated labels (`<label>` or `aria-label`)
- [ ] Buttons/links: descriptive text — not "Click here", "More", "Submit"
- [ ] Icon-only buttons: `aria-label`
- [ ] Heading hierarchy logical — no skipped levels
- [ ] Dynamic content changes announced (`aria-live` regions)

## Visual

- [ ] Text contrast ≥ 4.5:1 (normal), ≥ 3:1 (large text ≥ 18px / bold ≥ 14px)
- [ ] UI component contrast ≥ 3:1 against background
- [ ] Color not sole conveyor of information — icon, text, or pattern fallback
- [ ] Text resizable to 200% without horizontal scroll or content loss
- [ ] No flashing content > 3 times/second

## Touch / Mobile

- [ ] Touch targets ≥ 44×44px
- [ ] Sufficient spacing between interactive elements

## Forms

- [ ] Every input has visible label
- [ ] Required fields indicated beyond color alone
- [ ] Error messages specific, associated with field
- [ ] Error state uses icon/text/border — not color alone
- [ ] Known fields use autocomplete attributes

## Common Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| `div`/container as button | Not focusable, no keyboard | Use semantic `<button>` or `Semantics` |
| Missing `alt` / semantics | Invisible to assistive tech | Add descriptive text |
| Color-only state | Invisible to color-blind users | Add icon, text, or pattern |
| Autoplaying media | Disorienting | Add controls, no autoplay |
| Removing focus outlines | Users can't track focus | Style outlines, never remove |
| Empty links/buttons | "Link" announced with no description | Add text or `aria-label` |
