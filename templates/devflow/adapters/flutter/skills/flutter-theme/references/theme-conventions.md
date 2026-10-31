# Flutter Theme — project conventions

Loaded on demand from `../SKILL.md`.

## `lib/core/theme` layout

| File | Role |
| --- | --- |
| `_theme.dart` | Barrel: exports `theme`, `util`, `app_layout` |
| `theme.dart` | `MaterialTheme`: light/dark `ColorScheme` (explicit or `ColorScheme.fromSeed`), `theme(ColorScheme)` → `ThemeData` + component themes |
| `app_layout.dart` | Spacing / radius / sizing tokens (`AppLayout.inputBorderRadius`, …) |
| `util.dart` | `createTextTheme` — merges `google_fonts` into `TextTheme`; font pairing changes only here |

Optional: `theme_extensions/*` (`ThemeExtension`) for domain tokens (chips, charts, status colors).

## Color roles by intent

- `primary` / `onPrimary` — CTA and content on CTA
- `surface` / `onSurface` — page surfaces, default text
- `surfaceContainer*` — elevated containers and filled controls
- `outline` — borders, dividers
- `error` / `onError` — validation, destructive actions

## Component themes in `MaterialTheme.theme`

One method backs `light()`, `dark()` and contrast variants — one edit applies everywhere.

- Defined: `InputDecorationTheme` — `filled: true`, `fillColor: surfaceContainerHighest`, `OutlineInputBorder` radius `AppLayout.inputBorderRadius`; `outline` enabled, `primary` width 2 focused, `error` (width 2 focused-error), disabled `onSurface` 12% alpha.
- Add next, when first needed: `AppBarTheme`, `CardThemeData`, `ElevatedButtonThemeData`, `NavigationBarThemeData`.
