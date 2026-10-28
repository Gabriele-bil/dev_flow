# Skill: Flutter Theme — reference detail

Loaded on demand from `../SKILL.md`.

## 2) Color system conventions

Use explicit light/dark `ColorScheme` values in `lib/core/theme/theme.dart` (`MaterialTheme.lightScheme()`, `MaterialTheme.darkScheme()`, or `ColorScheme.fromSeed`). When extending palettes, keep using roles by intent:

- `primary` / `onPrimary`: CTA and content on CTA
- `surface` / `onSurface`: page surfaces + default readable text
- `surfaceContainer*`: elevated containers and **filled** controls (see inputs below)
- `outline`: borders and dividers
- `error` / `onError`: validation and destructive actions

Add `app_colors.dart` in the same folder only if you need non-semantic colors not covered by `ColorScheme` (for example `success`, `warning`, `info`).

## 3) Typography conventions

Configure Google Fonts and the merged `TextTheme` centrally (e.g. via `google_fonts` in `lib/core/theme/util.dart` or `app.dart`), then pass into `MaterialTheme` / `ThemeData`.

Use `TextTheme` as the source of truth in widgets. If needed, tweak one property with `copyWith`.

```dart
Text('Profile', style: text.titleLarge);
```

Rules:

- Do not create inline `TextStyle(...)` in feature widgets.
- Do not change font pairing in random screens; adjust central theme wiring instead.
- Use `labelLarge` for button text, `title*` for titles, `body*` for content.

## 4) Component theming strategy

Define component defaults once in `MaterialTheme.theme(ColorScheme)` in [`theme.dart`](lib/core/theme/theme.dart). That single method backs `light()`, `dark()`, and contrast variants, so **one** update applies to every brightness.

### Already defined

- **`InputDecorationTheme`**: `filled: true`; `fillColor: colorScheme.surfaceContainerHighest`; `OutlineInputBorder` with `BorderRadius.circular(AppLayout.inputBorderRadius)` for all states; `outline` when enabled; `primary` width 2 when focused; `error` (width 2 when focused error); `disabledBorder` uses `onSurface` at 12% alpha.

**Typical next targets** (add here when implemented)

- `AppBarTheme`
- `CardTheme` / `CardThemeData`
- `ElevatedButtonThemeData`
- `NavigationBarThemeData`

Keep shape, padding, border, and text styles in component themes so screens only compose widgets.

## 7) Repository layout (`lib/core/theme`)

| File                                                | Role                                                                  |
| --------------------------------------------------- | --------------------------------------------------------------------- |
| [`_theme.dart`](lib/core/theme/_theme.dart)         | Barrel: exports `theme`, `util`, `app_layout`                         |
| [`theme.dart`](lib/core/theme/theme.dart)           | `MaterialTheme`, `ColorScheme` values, `ThemeData` + component themes |
| [`app_layout.dart`](lib/core/theme/app_layout.dart) | Spacing/radii/sizing tokens (`AppLayout.inputBorderRadius`, …)        |
| [`util.dart`](lib/core/theme/util.dart)             | `createTextTheme` for Google Fonts merging                            |

Optional later: `theme_extensions/*` for `ThemeExtension` domain tokens (chips, charts) instead of scattered constants.
