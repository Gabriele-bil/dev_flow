---
name: flutter-theme
description: Use when implementing or refactoring Flutter visual styling (colors, typography, radii, spacing, component themes, light/dark mode). Enforces theme-first UI, semantic Material 3 tokens, and scoped overrides only when unavoidable.
---

# Skill: Flutter Theme

Use when touching Flutter UI styling.

## Objectives

- Keep visual decisions centralized under [`lib/core/theme`](lib/core/theme): `MaterialTheme` builds `ThemeData`; shared imports use [`lib/core/theme/_theme.dart`](lib/core/theme/_theme.dart).
- Prefer semantic Material 3 `ColorScheme` roles over raw values.
- Make styling predictable, reusable, and easy to review.
- Avoid local overrides that create design drift.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## 1) Theme-first rule (mandatory)

Never hardcode visual values in widgets. Pull from `ThemeData`, `ColorScheme`, `TextTheme`, and layout tokens (`AppLayout` in [`app_layout.dart`](lib/core/theme/app_layout.dart)).

```dart
final theme = Theme.of(context);
final colors = theme.colorScheme;
final text = theme.textTheme;

// Good
Container(color: colors.surface);
Text('Save', style: text.labelLarge?.copyWith(color: colors.onPrimary));
BorderRadius.circular(AppLayout.inputBorderRadius);

// Avoid
Container(color: Colors.white);
TextStyle(fontSize: 14, color: Colors.black);
BorderRadius.circular(12); // use AppLayout (or a new token) instead
```

## 2) Color system conventions

This app uses **explicit** light/dark `ColorScheme` values in [`theme.dart`](lib/core/theme/theme.dart) (`MaterialTheme.lightScheme()`, `MaterialTheme.darkScheme()`, plus high/medium contrast variants). When extending palettes, keep using roles by intent:

- `primary` / `onPrimary`: CTA and content on CTA
- `surface` / `onSurface`: page surfaces + default readable text
- `surfaceContainer*`: elevated containers and **filled** controls (see inputs below)
- `outline`: borders and dividers
- `error` / `onError`: validation and destructive actions

Add `app_colors.dart` in the same folder only if you need non-semantic colors not covered by `ColorScheme` (for example `success`, `warning`, `info`).

## 3) Typography conventions

Google Fonts and the merged `TextTheme` are produced by [`createTextTheme`](lib/core/theme/util.dart) in [`App`](lib/app.dart) (body: Outfit, display: Plus Jakarta Sans), then passed into `MaterialTheme`.

Use `TextTheme` as the source of truth in widgets. If needed, tweak one property with `copyWith`.

```dart
Text('Profile', style: text.titleLarge);
```

Rules:

- Do not create inline `TextStyle(...)` in feature widgets.
- Do not change font pairing in random screens; adjust `App` + `util.dart` / theme wiring instead.
- Use `labelLarge` for button text, `title*` for titles, `body*` for content.

## 4) Component theming strategy

Define component defaults once in `MaterialTheme.theme(ColorScheme)` in [`theme.dart`](lib/core/theme/theme.dart). That single method backs `light()`, `dark()`, and contrast variants, so **one** update applies to every brightness.

**Already defined**

- **`InputDecorationTheme`**: `filled: true`; `fillColor: colorScheme.surfaceContainerHighest`; `OutlineInputBorder` with `BorderRadius.circular(AppLayout.inputBorderRadius)` for all states; `outline` when enabled; `primary` width 2 when focused; `error` (width 2 when focused error); `disabledBorder` uses `onSurface` at 12% alpha.

**Typical next targets** (add here when implemented)

- `AppBarTheme`
- `CardTheme` / `CardThemeData`
- `ElevatedButtonThemeData`
- `NavigationBarThemeData`

Keep shape, padding, border, and text styles in component themes so screens only compose widgets.

## 5) Light and dark mode parity

Always keep light and dark coherent:

1. Changes go through `MaterialTheme.theme(colorScheme)` or both scheme factories if you edit raw `ColorScheme` constants.
2. Ensure contrast stays readable for text and icons.
3. Verify semantic meaning survives mode switch (error still error, selected still selected).

## 6) Scoped overrides (allowed, but rare)

If one widget needs a special style, wrap only that subtree with `Theme(data: ...copyWith(...))`.
Never override an entire screen to solve a local requirement.

```dart
Theme(
  data: Theme.of(context).copyWith(
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  ),
  child: const PetHighlightCard(),
);
```

## 7) Repository layout (`lib/core/theme`)

| File                                                | Role                                                                  |
| --------------------------------------------------- | --------------------------------------------------------------------- |
| [`_theme.dart`](lib/core/theme/_theme.dart)         | Barrel: exports `theme`, `util`, `app_layout`                         |
| [`theme.dart`](lib/core/theme/theme.dart)           | `MaterialTheme`, `ColorScheme` values, `ThemeData` + component themes |
| [`app_layout.dart`](lib/core/theme/app_layout.dart) | Spacing/radii/sizing tokens (`AppLayout.inputBorderRadius`, …)        |
| [`util.dart`](lib/core/theme/util.dart)             | `createTextTheme` for Google Fonts merging                            |

Optional later: `theme_extensions/*` for `ThemeExtension` domain tokens (chips, charts) instead of scattered constants.

## 8) Review checklist

Before finalizing UI changes, confirm:

- [ ] no hardcoded hex or `Colors.*` in feature widgets
- [ ] no inline `TextStyle(...)` except inside `lib/core/theme` (or font wiring in `App`)
- [ ] spacing/radius uses `AppLayout` (or new tokens in the same file)
- [ ] component defaults live in `MaterialTheme.theme`, not on screens
- [ ] light and dark (and contrast variants if touched) stay visually consistent
- [ ] one-off overrides are scoped to the smallest possible subtree

## 9) Common anti-patterns

- **Hardcoded color in widget** → use `colorScheme` role
- **Local typographic scale drift** → use `textTheme` + `copyWith`
- **Repeated button/input style in pages** → move to component themes in `theme.dart`
- **Using `Colors.white/black` for readability** → use `on*` tokens
- **Theme override at page level for one widget** → scope `Theme` override locally

## I/O Reference

|                |                                                                                 |
| -------------- | ------------------------------------------------------------------------------- |
| Trigger        | New UI screens, new components, or any change to `lib/core/theme`               |
| Reads          | `lib/core/theme/` layout, `constitution.md` (styling conventions)               |
| Invoked by     | `devflow.plan` (when UI is introduced), `devflow.implement`, `devflow.beautify` |
| Related skills | `flutter-layout`                                                                |
