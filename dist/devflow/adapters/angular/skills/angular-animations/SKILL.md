---
name: angular-animations
description: Angular v22+ DOM animations. Native CSS animate.enter/leave by default; @angular/animations DSL for pre-v20.2 only. Triggers on enter/leave, state transitions, or animation-library (GSAP) integration.
---

# Angular Animations

Animate DOM enter/leave + state transitions. Check `package.json` Angular version first — drives which approach applies.

## Native CSS — `animate.enter` / `animate.leave` (v20.2+, Default)

Apply CSS classes during enter/leave phases. Angular removes enter classes on completion; for leave, Angular waits for animation to finish before removing the element.

```html
@if (isShown()) {
  <div class="enter-container" animate.enter="enter-animation">
    <p>The box is entering.</p>
  </div>
}
```

```css
.enter-animation { animation: slide-fade 1s; }

@keyframes slide-fade {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
```

### Event Bindings — Custom/Third-Party Logic

```html
@if (show()) {
  <div (animate.leave)="onLeave($event)">...</div>
}
```

```typescript
import { AnimationCallbackEvent } from "@angular/core";

onLeave(event: AnimationCallbackEvent) {
  // custom logic (e.g. GSAP)
  event.animationComplete(); // REQUIRED — Angular waits for this before removing element
}
```

`event.animationComplete()` is mandatory on `(animate.leave)` handlers — omitting it leaks DOM nodes Angular thinks are still animating.

## State-Based Class Toggling

```html
<div [class.open]="isOpen()">...</div>
```

```css
div { transition: height 0.3s ease-out; height: 100px; }
div.open { height: 200px; }
```

Auto-height via CSS grid trick:

```css
.container { display: grid; grid-template-rows: 0fr; transition: grid-template-rows 0.3s; }
.container.open { grid-template-rows: 1fr; }
.container > div { overflow: hidden; }
```

Stagger list items with `animation-delay`/`transition-delay` per index. Run animations in parallel via shorthand: `animation: rotate 3s, fade-in 2s;`. Programmatic control: `element.getAnimations()`.

## Legacy DSL (`@angular/animations`) — Pre-v20.2 / Heavy Existing Usage Only

```typescript
bootstrapApplication(App, { providers: [provideAnimationsAsync()] });
```

```typescript
import { trigger, state, style, animate, transition } from "@angular/animations";

@Component({
  animations: [
    trigger("openClose", [
      state("open", style({ opacity: 1 })),
      state("closed", style({ opacity: 0 })),
      transition("open <=> closed", [animate("0.5s")]),
    ]),
  ],
  template: `<div [@openClose]="isOpen() ? 'open' : 'closed'">...</div>`,
})
export class OpenClose {
  protected readonly isOpen = signal(true);
}
```

**Never mix legacy DSL and `animate.enter`/`animate.leave` in the same component** — conflicting animation systems produce undefined timing behavior.

## Route Transitions

Cross-route animations use the View Transitions API via `withViewTransitions()` — covered in `angular-routing` (Route Transition Animations section). CSS for `::view-transition-old/new` MUST live in global `src/styles.css`, never component-scoped — view encapsulation blocks pseudo-element selectors.

## I/O Reference

|            |                                                                   | |
| ---------- | ----------------------------------------------------------------- | |
| Reads      | Active component/template/style files, `package.json` (Angular version), `@devflow/adapters/angular/ADAPTER.md` | |
| Writes     | New or refactored animation triggers, CSS keyframes/transitions, animation event handlers | |
| Invoked by | `devflow.implement`, `devflow.beautify`                          | |
