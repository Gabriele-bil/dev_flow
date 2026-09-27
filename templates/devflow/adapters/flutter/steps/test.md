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

Level-4 goal-backward verification targets (`devflow.test` Step 6b):

- **Level 4a (Services / State):** Run unit/integration tests targeting Riverpod providers and repositories.
- **Level 4b (UI / Web & Device Workflow):** Run integration specs on target device or Chrome browser:

```bash
# Chrome (Web):
flutter test integration_test/features/[feature-name]/ -d chrome

# Mobile emulator:
flutter test integration_test/features/[feature-name]/ -d emulator-[ID]
```

When verifying Flutter Web in an agentic browser environment:
1. Run local web build or dev server (`flutter run -d web-server --web-port=8080`).
2. Navigate to web app; confirm widget tree mounts without uncaught exceptions or console errors.
3. Verify widget interaction (tap, scroll, form entry) and responsive breakpoints.
4. Record confirmation evidence in `verification.md`.

No integration spec covering the AC and no web/device runner available → level 4 `N/A` (verdict PARTIAL).
