# Angular Components — project decisions

Loaded on demand from `../SKILL.md`. Standard APIs (`input`, `output`, `model`, `viewChild`, `contentChildren`, `@defer`, `NgOptimizedImage`): check current docs with Context7 (`/websites/angular_dev`) when unsure of an option.

## Defaults (v22)

- Standalone and `OnPush` are defaults — do not use `standalone: true`; omit `changeDetection`. `ChangeDetectionStrategy.Eager` (was `Default`) only for test wrappers or a justified legacy component.
- `inject()` over constructor DI. Root singletons: `@Service()`.
- Child/presentational components: inputs in, outputs out. No store or service injection below the page unless the component is the feature's container.

## Derived state — `computed()` / `linkedSignal()`, not `effect()`

`effect()` that writes another signal = hidden reactive chain + `ExpressionChangedAfterItHasBeenChecked` risk. Do not use it to sync state.

```typescript
// reset to first tab when tabs change, user can still pick another
selectedTab = linkedSignal(() => this.tabs()[0]);

// keep previous selection if still present
selected = linkedSignal<Item[], Item | undefined>({
  source: this.items,
  computation: (items, prev) => items.find((i) => i.id === prev?.value?.id) ?? items[0],
});
```

`effect()` only for non-signal sinks (localStorage, logging, third-party imperative API), with `onCleanup` for timers/listeners.

## Host and DOM

- `host: {}` metadata for classes, attributes, listeners. Do not use `@HostBinding` / `@HostListener`.
- Static host attribute at creation: `inject(new HostAttributeToken('type'), { optional: true })`.
- DOM work after render: `afterNextRender` (once) or `afterRenderEffect({ earlyRead, write, read })` (reactive, phased). Avoid `mixedReadWrite`. `afterRender` was removed — use `afterEveryRender` only for non-reactive per-render work.

## Templates

- Native control flow only (`@if`, `@for` with `track`, `@switch`).
- Several values, one block: consecutive `@case` lines (`@case ('a')` newline `@case ('b') { … }`), one `@case` per value.
- Exhaustive union switch: `@let s = status();` then `@switch (s) { … @default never; }` — narrowing needs a variable, not a signal call.
- Arrow functions (expression body only) and spread are valid in template expressions; no pipes inside arrow bodies.
- `[class.x]` / `[style.x]` bindings instead of `ngClass` / `ngStyle`.
- Images: `NgOptimizedImage` (`ngSrc`), `priority` on the LCP image.
- Heavy below-fold UI: `@defer (on viewport)` with `@placeholder`.

## Accessibility baseline

Interactive custom element: correct `role`, `aria-*` from signals via `host`, keyboard handlers (Enter/Space), visible focus. Prefer native `<button>` over `role="button"` divs; complex widgets → `angular-aria`.
