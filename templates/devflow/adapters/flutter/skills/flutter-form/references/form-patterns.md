# Flutter Forms — Code Patterns

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

## Submit and read values safely

```dart
void onSubmit(GlobalKey<FormBuilderState> formKey) {
  final isValid = formKey.currentState?.saveAndValidate() ?? false;
  if (!isValid) return;

  final values = formKey.currentState!.value;
  // map values -> notifier/repository input
}
```

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

## Validator composition example

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
