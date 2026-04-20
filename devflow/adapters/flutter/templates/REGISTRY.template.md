<!-- devflow-managed:start:patterns -->
| Pattern | When | Path |
|---|---|---|
| Riverpod AsyncNotifier | Async feature state | `lib/features/<feature>/providers/...` |
| Responsive LayoutBuilder | Multi-breakpoint UI | `lib/features/<feature>/pages/page.dart` |
| Repository Contract | Data/domain boundary | `lib/features/<feature>/domain/...` |
| Slang Localization | Any user-facing text | `assets/i18n/*.json` |
<!-- devflow-managed:end:patterns -->

<!-- devflow-managed:start:conventions -->
**Naming:** feature folders `snake_case`; page entry `pages/page.dart`
**Branches:** `feat/[NNN]-<name>`, `fix/[NNN]-<name>`
**Commits:** `<type>: <desc>` (`feat|fix|chore|docs|perf`)
**Format:** `dart format .`
**Analyze:** `flutter analyze`
**Test:** `flutter test test/ --reporter compact`
<!-- devflow-managed:end:conventions -->
