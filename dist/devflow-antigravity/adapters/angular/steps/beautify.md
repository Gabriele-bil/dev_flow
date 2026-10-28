# Angular adapter — Beautify step

Loaded by `devflow-beautify` together with the adapter core (`ADAPTER.md`).

## Beautify: commands

Same as implement pipeline: `lint`, `test`, `build`.

### Beautify: performance profiling trigger

Profile only when the plan calls out performance or a **Critical**-severity hotspot is flagged:

- Use Angular DevTools (Component profiler, Change detection cycles) before refactoring rendering performance.
- Investigate excessive change-detection cycles by checking signal/Observable scope before adding `OnPush` or `trackBy`.
- Heavy computation in templates or services called on every render cycle — move to computed signals or memoized pipes.

Default beautify relies on heuristics (avoid unnecessary recalculations in getters, narrow RxJS subscriptions, avoid `combineLatest` with broad streams). Profile only when warranted.

### Beautify: Angular-specific review axes

Apply core `devflow-beautify` axes, then evaluate touched code with relevant Angular skills:

- `angular-architecture`
- `angular-component`
- `angular-forms`
- `angular-http`
- `angular-state`
- `angular-routing`
- `angular-aria`
- `angular-animations`

### Beautify: accessibility checks

Apply these Angular-specific accessibility checks in addition to core accessibility axis:

- Interactive custom components have `role` attribute set correctly (`button`, `dialog`, `menu`, etc.)
- Icon-only buttons and controls include `aria-label` or `aria-labelledby`
- Form fields have associated `<label>` or `aria-label`; error messages linked via `aria-describedby`
- Modal/dialog components trap focus on open (`cdkTrapFocus` or equivalent) and restore on close
- Keyboard navigation: custom dropdowns, menus, and carousels handle arrow key / Enter / Escape
- Color contrast: use design-system tokens; no hardcoded hex that may fail WCAG AA

Severity: **Critical** for screen-reader-blocking issues; **Required** for missing labels on form controls; **Nit** for enhancement.
