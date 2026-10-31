---
name: angular-animations
description: Angular v22+ DOM animations with native CSS and animate.enter/animate.leave. Triggers on enter/leave, state transitions, legacy animation migration, or animation-library (GSAP) integration.
---

# Angular Animations

## Purpose

Animate enter/leave and state transitions with native CSS plus `animate.enter`/`animate.leave` (v20.2+). Migrate legacy animation code when touched.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no animation, enter/leave or transition code touched).
- Route-to-route transitions → `angular-routing` (`withViewTransitions()`).
- Static styling, tokens, dark mode → `angular-theme`.

## Rules

- **`@angular/animations` is deprecated (v20.2), removal planned in v23** — do not use it in new code. Touching a component that uses `trigger()`/`[@x]` bindings or `provideAnimationsAsync()` → migrate it to native CSS in the same change (Angular docs: "Migrating away from Angular's Animations package"). Check current docs with Context7 for the mapping.
- Enter: `animate.enter="css-class"` (or CSS `@starting-style`). Leave: `animate.leave="css-class"` — Angular waits for the animation, then removes the element.
- Keep animation CSS in the component stylesheet; keyframes/tokens shared across components → `src/styles/` (`angular-theme`).

```html
@if (isShown()) {
  <div class="panel" animate.enter="slide-in" animate.leave="fade-out">…</div>
}
```

```css
.slide-in { animation: slide-fade 200ms ease-out; }
.fade-out { opacity: 0; transition: opacity 150ms ease-in; }
@keyframes slide-fade { from { opacity: 0; transform: translateY(8px); } }
```

## JS / third-party (GSAP, anime.js)

Bind the event form and call `animationComplete()` when done; otherwise Angular removes the element only after `MAX_ANIMATION_TIMEOUT` (4 s default).

```typescript
onLeave(event: AnimationCallbackEvent) { // from @angular/core
  gsap.to(event.target, { opacity: 0, onComplete: () => event.animationComplete() });
}
```

```html
<div (animate.leave)="onLeave($event)">…</div>
```

## State transitions

Toggle a class from a signal (`[class.open]="isOpen()"`) and let CSS `transition` animate it. Auto-height: `grid-template-rows: 0fr → 1fr`. Stagger lists with per-index `animation-delay`. Respect `prefers-reduced-motion` (disable or shorten).

## I/O Reference

|            |                                                                   |
| ---------- | ----------------------------------------------------------------- |
| Reads      | Active component/template/style files, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or migrated enter/leave animations, CSS keyframes/transitions, animation event handlers |
| Invoked by | `devflow.implement`, `devflow.beautify`                          |
