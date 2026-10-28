---
name: angular-forms
description: Angular v22 Signal Forms — two-way binding, schema validation, field state, dynamic forms. Production-ready default. Triggers on form creation, validation, multi-step, or conditional fields. Skip for template-driven forms or Formly/ngx-formly.
---

# Angular Signal Forms

Build type-safe, reactive forms with Signal Forms API. One model signal = source of truth.

Signal Forms stable, production-ready in Angular v22.

## Strict Rules

These traps break builds or silently corrupt form behavior — pre-empt them:

- **Non-null model** — never `null`/`undefined` in initial model values. Use `''` for strings, `0` for numbers, `[]` for arrays, nested object defaults for groups. Inputs reject `null`.
- **Calling convention** — fields are functions: `form.field().valid()`, NOT `form.field.valid`. `form.field()` = `FieldState` (signals); `form.field` = `FormField` (structure, no flags). Exception: `.length` on arrays is structural, no `()`.
- **Forbidden `[formField]` attributes** — never set `min`, `max`, `value`, `[value]`, `[disabled]`, `[readonly]`, `[attr.min]`, `[attr.max]` alongside `[formField]`. `[formField]` owns these; conflicts throw `NG8022`. Express constraints via schema rules (`min()`, `max()`, `disabled()`, `readonly()`).
- **Async validation** — use `validateAsync()`, never `validate()`, for async work. `params` MUST be a function (`({ value }) => value()`); `onError` is REQUIRED, not optional.
- **`debounce()`** — delays model sync (e.g. `debounce(s.username, 300)`) for expensive downstream work (async validation, search).
- **`applyEach`/`applyWhen` nuances** — `applyEach` callback takes exactly ONE argument (the item path), never `(item, index)`. `applyWhen` needs 3 args: `(path, condition, schemaFn)`; condition reads via `valueOf`/`stateOf`, paths are not signals/callable inside the schema.
- **No `$parent` in nested `@for`** — capture outer index with `let outerIndex = $index`.

Full pitfalls table + examples: [references/form-patterns.md](references/form-patterns.md#strict-rules--common-pitfalls).

Full field/form patterns (setup, models, state, validation, conditional fields, submission, arrays, error display, reset) → [references/form-patterns.md](references/form-patterns.md).

## I/O Reference

|            |                                                           |
| ---------- | --------------------------------------------------------- |
| Reads      | Active form files, `@devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular signal-based form files         |
| Invoked by | `devflow.implement`, `devflow.beautify`                   |
