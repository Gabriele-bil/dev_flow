# Flutter adapter — PR step

Loaded by `devflow-pr` together with the adapter core (`ADAPTER.md`).

## PR: verification

Before push:

```bash
flutter analyze   # expect: No issues found!
flutter test test/ --reporter compact   # expect: All tests passed!
```

### PR body checklist (copy into PR description)

- [ ] All unit tests passing
- [ ] Integration tests passing on Android emulator
- [ ] Integration tests passing on Chrome
- [ ] `flutter analyze` reports no issues
- [ ] `dart format` applied
- [ ] No hardcoded TODO or placeholder comments
- [ ] `registry.md` updated if new patterns were introduced
