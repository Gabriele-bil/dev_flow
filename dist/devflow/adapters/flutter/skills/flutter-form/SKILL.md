---
name: flutter-form
description: Use when implementing or refactoring Flutter forms with `flutter_form_builder` and `form_builder_validators`, including validation, submit flow, edit forms, and multi-step wizards.
---

# Flutter Forms

## Scope

Default stack for this repository:

- `flutter_form_builder` for fields and form state.
- `form_builder_validators` for composable validation.

Prefer package primitives over custom controllers/ad-hoc validation.

Full code: `references/form-patterns.md`.

## Form skeleton rules

- Use `GlobalKey<FormBuilderState>` for `FormBuilder`.
- Keep field names unique and `snake_case`.
- Use `AutovalidateMode.onUserInteraction` as default UX baseline.
- Call `saveAndValidate()` before reading `.value`. Use `validate()` + `instantValue` only when current values are needed without save side effects.
- Keep business mapping/submit side effects in notifier/use-case layer, not inline in widgets.

## Field patterns

- **Text**: standard `FormBuilderTextField` with composed validators.
- **Numeric**: normalize with `valueTransformer` (e.g. `double.tryParse`) — domain type is numeric, not string.
- **Select (dropdown/radio/chips)**: serializable primitives (`String`, `int`) as UI values, map to domain enum/value objects on submit.
- **Date**: constrain with `firstDate`/`lastDate`, validate domain constraints (e.g. "not in future") via composed validators.

## Validator conventions

`FormBuilderValidators.compose([...])`, order intentional: 1) presence (`required`) 2) shape (`email`, `numeric`, `match`) 3) range/domain (`min`, `max`, custom validator).

## Edit mode and programmatic updates

- Use `initialValue` for first render prefill.
- For async-loaded edit data, update form state programmatically (e.g. `patchValue`) once data is available.
- Keep source of truth in provider/notifier state; form is an editing surface.

## Multi-step (wizard) forms

Pattern: 1) one `FormBuilder` key per step 2) validate/save step 3) merge into notifier-held aggregate payload 4) final step triggers repository submit. Do not store cross-step aggregate payload in widget-local mutable state.

## Loading, disable, and feedback

- Disable submit actions while async submit is running.
- Show inline error messages through validators for field errors.
- Show page-level/server errors outside fields (banner/snackbar/error section), not as fake field validation.

## Accessibility and UX baseline

- Always provide meaningful `InputDecoration(labelText: ...)`.
- Keep error text specific and actionable.
- Do not use `AutovalidateMode.always` by default; prefer `onUserInteraction`.

## Anti-patterns

| Avoid | Prefer |
| --- | --- |
| Reading `.value` before validation | `saveAndValidate()` then read `.value` |
| Enum instances as raw field values | serializable value + mapping on submit |
| Business submit logic inside widget callback | notifier/use-case orchestrates submit |
| Per-field custom imperative checks everywhere | shared composed validators |
| Recreating `GlobalKey` every rebuild | stable key lifecycle (`State` or `useMemoized`) |
| Wizard payload in widget state | aggregate payload in notifier/provider |

## References used for this skill update

- Context7: `/flutter-form-builder-ecosystem/flutter_form_builder` (README examples and API usage)
- Context7: `/websites/flutter_dev` (Flutter form validation and `autovalidateMode` guidance)

## I/O Reference

| | |
| --- | --- |
| Trigger | Any feature that introduces or modifies a form (login, signup, wizard steps, edit screens) |
| Reads | `constitution.md` (architecture conventions), `registry.md` (existing form patterns) |
| Invoked by | `devflow.implement` (form screens), `devflow.plan` (when wizard or multi-field form is planned) |
| Related skills | `flutter-riverpod` (form state via notifier), `flutter-models` (form payload mapping) |
