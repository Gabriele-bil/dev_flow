# Angular Signal Forms — project decisions

Loaded on demand from `../SKILL.md`. Signal Forms API (`@angular/forms/signals`) still moves between minors: check current docs with Context7 (`/websites/angular_dev`, "signal forms …") before writing any rule, validator or `submit()` call.

## Shape

- One model `signal<T>()` per form = source of truth; `form(model, schemaFn)` in the component (or a `*.form.ts` helper for reuse).
- Non-null initial values: `''`, `0`, `[]`, nested object defaults. Model fields reject `null`.
- Reusable rules and `validateHttp` schemas live in `validators/` (page or `shared/`), not inline in the component — keeps HTTP out of components (`angular-http`).
- Large forms: split by sub-tree component; pass `form.address` etc. as `input.required<FieldTree<Address>>()`.

## Conditional state — `{ when }` only

`hidden()`, `disabled()`, `readonly()` take a config object. Positional logic fn is deprecated.

```typescript
form(this.model, (p) => {
  hidden(p.publicUrl, { when: ({ valueOf }) => !valueOf(p.isPublic) });
  // string = disabled with reason (read via disabledReasons()); return false explicitly to enable
  disabled(p.couponCode, { when: ({ valueOf }) => (valueOf(p.total) < 50 ? 'Min order 50' : false) });
});
```

Template still gates rendering: `@if (!form.publicUrl().hidden()) { ... }`. Hidden/disabled/readonly fields do not count toward validity.

## Pitfalls (compile errors or silent bugs)

| Wrong | Right |
| --- | --- |
| `form.field.valid()` | `form.field().valid()` — `form.field` is structure, `form.field()` is state |
| `form.invalid()` | `form().invalid()` |
| `form.items().length` | `form.items.length` (structural) |
| `[value]`, `[disabled]`, `min`, `readonly` attrs next to `[formField]` | schema rules — attribute conflict throws NG8022 |
| `validate()` for async checks | `validateHttp()` / `validateAsync()`; `params` is a function, `onError` required |
| `applyEach(s.items, (item, i) => …)` | one arg: `(item) => …` |
| `applyWhen(cond, fn)` | `applyWhen(path, ({ valueOf }) => …, schemaFn)`; paths are not callable inside rules |
| `$parent.$index` in nested `@for` | `let outer = $index` |
| `<input type="checkbox">` bound to `string[]` | checkbox binds `boolean` only |

## Custom controls

Own widgets (incl. `@angular/aria` wrappers) implement `FormValueControl<T>` (`value = model<T>()`, optional `disabled`/`invalid`/`errors` inputs, `touch` output) and are bound with `[formField]`.

## Submit

`submit(form, async () => …)` marks all fields touched and runs the action only when valid; returns `Promise<boolean>`. Server errors map back as validation errors from the action's return value.

## Testing

Act → wait → assert on field state, not snapshots: set model or dispatch `input` event, `await fixture.whenStable()`, assert `form.x().valid()` / `errors()[0].kind`.
