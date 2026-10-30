---
name: flutter-form
description: Use when implementing or refactoring Flutter forms with `flutter_form_builder` and `form_builder_validators`, including validation, submit flow, edit forms, and multi-step wizards.
---

# Skill: Flutter Forms

## Purpose

Forms on `flutter_form_builder` + `form_builder_validators`: field naming, validation order, submit through notifier, edit prefill, wizards.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Single search box or toggle with no validation → plain widget + provider
- Submit payload → domain mapping rules → `flutter-models`

## Rules

- `GlobalKey<FormBuilderState>` held stably (`State` field or `useMemoized`) — never recreated per build.
- Field `name` unique, `snake_case`.
- `autovalidateMode: AutovalidateMode.onUserInteraction` default; never `always`.
- Read values only after `saveAndValidate()` → `.value`. `validate()` + `instantValue` only when values are needed without save side effects.
- Validators: `FormBuilderValidators.compose([...])` in order presence (`required`) → shape (`email`, `numeric`, `match`) → range/domain (`min`, `max`, custom). Shared custom validators, not per-field imperative checks.
- Numeric/date fields: `valueTransformer` to domain type (`double.tryParse`); dates bounded by `firstDate` / `lastDate`.
- Select fields (dropdown/radio/chips): primitive values (`String`, `int`); map to enums/value objects on submit.
- Labels and error text from slang (`InputDecoration(labelText: t.pets.name)`), specific and actionable.
- Submit: widget calls one notifier method; mapping + repository call live there. Disable submit while running.
- Field errors via validators; server/page errors in banner/snackbar/error section — never fake field validation.
- Edit mode: `initialValue` for first render; async-loaded data → `patchValue` once available. Source of truth stays in the provider.
- Wizard: one `FormBuilder` key per step → validate/save step → merge into notifier-held aggregate → last step submits. No cross-step payload in widget state.

```dart
FormBuilderTextField(
  name: 'weight',
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: t.pets.weight),
  valueTransformer: (v) => double.tryParse(v ?? ''),
  validator: FormBuilderValidators.compose([
    FormBuilderValidators.required(),
    FormBuilderValidators.numeric(),
    FormBuilderValidators.min(0.1),
  ]),
);

void onSubmit() {
  final form = formKey.currentState;
  if (form == null || !form.saveAndValidate()) return;
  ref.read(petFormProvider.notifier).submit(form.value);
}
```

Validator names and field widgets change between `form_builder_validators` majors — check Context7 (`/flutter-form-builder-ecosystem/flutter_form_builder`) before using one not shown here.

## Anti-Patterns

| Avoid | Prefer |
| --- | --- |
| Reading `.value` before validation | `saveAndValidate()` then `.value` |
| Enum instances as field values | Primitive value + mapping on submit |
| Submit logic in widget callback | Notifier method orchestrates submit |
| Wizard payload in widget state | Aggregate in notifier |

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `*/forms/*.dart`, `*_form.dart`, files using `FormBuilder` |
| Reads | `constitution.md` (architecture conventions), `registry.md` (form patterns) |
| Invoked by | `devflow.implement` (form screens), `devflow.plan` (wizard or multi-field form planned) |
| Related skills | `flutter-riverpod` (submit via notifier), `flutter-models` (payload mapping) |
