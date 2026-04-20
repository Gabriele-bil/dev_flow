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

## Standard form skeleton

```dart
final formKey = GlobalKey<FormBuilderState>();

FormBuilder(
  key: formKey,
  autovalidateMode: AutovalidateMode.onUserInteraction,
  child: Column(
    children: [
      FormBuilderTextField(
        name: 'name',
        decoration: const InputDecoration(labelText: 'Name'),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.minLength(2),
        ]),
      ),
      ElevatedButton(
        onPressed: () => onSubmit(formKey),
        child: const Text('Save'),
      ),
    ],
  ),
)
```

Rules:

- Use `GlobalKey<FormBuilderState>` for `FormBuilder`.
- Keep field names unique and `snake_case`.
- Use `AutovalidateMode.onUserInteraction` as default UX baseline.

## Submit and read values safely

```dart
void onSubmit(GlobalKey<FormBuilderState> formKey) {
  final isValid = formKey.currentState?.saveAndValidate() ?? false;
  if (!isValid) return;

  final values = formKey.currentState!.value;
  // map values -> notifier/repository input
}
```

Guidance:

- Call `saveAndValidate()` before reading `.value`.
- Use `validate()` + `instantValue` only when you need current values without save side effects.
- Keep business mapping/submit side effects in notifier/use-case layer, not inline in widgets.

## Field patterns

### Text

```dart
FormBuilderTextField(
  name: 'name',
  textCapitalization: TextCapitalization.words,
  decoration: const InputDecoration(labelText: 'Name'),
  validator: FormBuilderValidators.compose([
    FormBuilderValidators.required(),
    FormBuilderValidators.maxLength(50),
  ]),
)
```

### Numeric input

```dart
FormBuilderTextField(
  name: 'weight',
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
  valueTransformer: (value) => value == null ? null : double.tryParse(value),
  validator: FormBuilderValidators.compose([
    FormBuilderValidators.required(),
    FormBuilderValidators.numeric(),
    FormBuilderValidators.min(0.1),
  ]),
)
```

Always normalize string input with `valueTransformer` when domain type is numeric/date-like.

### Select fields (dropdown/radio/chips)

Use serializable primitives (`String`, `int`) as UI values, then map to domain enum/value objects in submit mapping.

### Date fields

Constrain with `firstDate`/`lastDate` and validate domain constraints (for example "not in future") via composed validators.

## Validator conventions

Use `FormBuilderValidators.compose([...])` and keep order intentional:

1. presence (`required`)
2. shape (`email`, `numeric`, `match`)
3. range/domain (`min`, `max`, custom validator)

Example:

```dart
validator: FormBuilderValidators.compose([
  FormBuilderValidators.required(),
  FormBuilderValidators.email(),
  (value) {
    if (value == null) return null;
    return value.endsWith('@example.com')
        ? null
        : 'Use a company email';
  },
]),
```

## Edit mode and programmatic updates

- Use `initialValue` for first render prefill.
- For async-loaded edit data, update form state programmatically (for example with `patchValue`) once data is available.
- Keep the source of truth in provider/notifier state; form is an editing surface.

## Multi-step (wizard) forms

Pattern:

1. one `FormBuilder` key per step
2. validate/save step
3. merge into notifier-held aggregate payload
4. final step triggers repository submit

Do not store cross-step aggregate payload in widget-local mutable state.

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
|---|---|
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
|---|---|
| Trigger | Any feature that introduces or modifies a form (login, signup, wizard steps, edit screens) |
| Reads | `constitution.md` (architecture conventions), `registry.md` (existing form patterns) |
| Invoked by | `devflow.implement` (form screens), `devflow.plan` (when wizard or multi-field form is planned) |
| Related skills | `flutter-riverpod` (form state via notifier), `flutter-models` (form payload mapping) |