# Flutter adapter — Beautify step

Loaded by `devflow-beautify` together with the adapter core (`ADAPTER.md`).

## Beautify: commands

Same as implement: `dart format .`, `flutter analyze`, conditional `build_runner` after edits.

### Beautify: Flutter-specific review axes

Apply these in addition to core `devflow-beautify` axes:

- **Theme-first UI:** no hardcoded colors/text styles when theme tokens exist (`flutter-theme`).
- **Presentation boundaries:** no business/data logic leaking into widgets/screens.
- **Riverpod scope:** avoid broad watches; use `.select()` when only a sub-field is needed (`flutter-riverpod`).
- **Render cost:** avoid expensive work in `build()`; prefer lazy lists (`ListView.builder`/slivers) for large datasets.
- **Responsive layout:** use `LayoutBuilder` + project breakpoints (`AppBreakpointWidth` / `AppBreakpointConstraints`) instead of raw viewport literals.

### Beautify: accessibility checks

Apply these Flutter-specific accessibility checks in addition to core accessibility axis:

- Custom interactive widgets have `Semantics` wrappers with `label`, `button`, `onTap` as appropriate
- Image-only or icon-only buttons include `Semantics(label: ...)` or `tooltip`
- Color contrast: use semantic theme tokens (never hardcode colors that might fail WCAG AA)
- `ExcludeSemantics` used only when intentional (decorative content)
- `FocusNode` management correct for keyboard navigation in custom overlays and dialogs

Severity: **Critical** for screen-reader-blocking issues (missing semantics on primary actions); **Required** for contrast violations; **Nit** for enhancement.

### Beautify: performance profiling trigger

Profile only when plan calls out performance or when a likely hotspot is found:

- Use Flutter DevTools (Performance/CPU/Timeline) before major perf refactors.
- Investigate dropped frames/scroll jank by checking rebuild scope (`Provider`/`Consumer` granularity) before micro-optimizations.
- For large images in lists, follow project decoding/caching patterns.
