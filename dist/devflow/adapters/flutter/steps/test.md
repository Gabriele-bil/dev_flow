# Flutter adapter — Test step

Loaded by `devflow-test` (and `devflow-backprop` for test conventions) together with the adapter core (`ADAPTER.md`).

## Test: layout and commands

### Coverage threshold

`test-coverage-threshold: 80`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: mirror `lib/` under `test/`, suffix `_test.dart`.  
- Integration: `integration_test/features/[feature-name]/[flow]_test.dart`.

### Commands

Unit tests:

```bash
flutter test test/features/[feature-name]/ --reporter expanded
```

Integration (sequential: Android then Chrome):

```bash
flutter test integration_test/features/[feature-name]/ -d emulator-[ID]
```

Use `flutter_test` and Riverpod test utilities; mock Supabase — no real network in unit tests.

### Responsive tests

For UI screens, assert layout variants at compact vs expanded widths using `MediaQuery` overrides per project patterns (`AppBreakpoints`).

### Verify (runtime)

Level-4 goal-backward verification target (`devflow.test` Step 6b). Run only specs covering the AC under verification:

```bash
flutter test integration_test/features/[feature-name]/ -d emulator-[ID]
```

No integration spec covering the AC → level 4 `N/A` (verdict PARTIAL).
