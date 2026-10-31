---
name: angular-forms
description: Angular v22 Signal Forms — two-way binding, schema validation, field state, dynamic forms. Production-ready default. Triggers on form creation, validation, multi-step, or conditional fields. Skip for template-driven forms or Formly/ngx-formly.
---

# Angular Signal Forms

## Purpose

Build type-safe forms with Signal Forms (`@angular/forms/signals`): one model signal = source of truth, rules in a schema function.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no form, form component or validator touched).
- Template-driven forms, Formly/ngx-formly, or legacy Reactive Forms kept as-is.
- Accessible widget markup itself (Combobox, Listbox) → `angular-aria`; only the `[formField]` binding lives here.

## Rules

- **Non-null model** — `''`, `0`, `[]`, nested defaults; never `null`/`undefined`.
- **Calling convention** — `form.field().valid()`, not `form.field.valid()`. Arrays: `form.items.length` (structural, no `()`).
- **`[formField]` owns `value`, `disabled`, `readonly`, `min`, `max`** — never set them as attributes/bindings on the same element (NG8022). Use schema rules.
- **Conditional state** — `hidden(p.x, { when })`, `disabled(p.x, { when })`, `readonly(p.x, { when })`. Positional logic fn deprecated.
- **Async validation** — `validateHttp()` or `validateAsync()`, never `validate()`. Schema lives in `validators/`, not inline in the component.
- **`debounce(p.x, ms)`** for expensive downstream work (async validation, search).
- **`applyEach`** callback takes one arg; **`applyWhen`** takes `(path, condition, schemaFn)`.
- **Submit** with `submit(form, async () => …)` — marks touched, runs only when valid.
- **Custom controls** implement `FormValueControl<T>` and bind via `[formField]`.

Pitfalls table, `{ when }` example, custom control and test notes: [references/form-patterns.md](references/form-patterns.md). Check current docs with Context7 before writing Signal Forms rules — API still moves between minors.

## I/O Reference

|            |                                                           |
| ---------- | --------------------------------------------------------- |
| Reads      | Active form/validator files, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored Angular signal-based form files         |
| Invoked by | `devflow.implement`, `devflow.beautify`                   |
