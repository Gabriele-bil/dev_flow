---
name: flutter-theme
description: Use when implementing or refactoring Flutter visual styling (colors, typography, radii, spacing, component themes, light/dark mode). Enforces theme-first UI, semantic Material 3 tokens, and scoped overrides only when unavoidable.
---

# Skill: Flutter Theme

Use when touching Flutter UI styling.

## Objectives

- Keep visual decisions centralized under `lib/core/theme`: `MaterialTheme` builds `ThemeData`; shared imports use `lib/core/theme/_theme.dart`.
- Prefer semantic Material 3 `ColorScheme` roles over raw values.
- Make styling predictable, reusable, and easy to review.
- Avoid local overrides that create design drift.

## 1) Theme-first rule (mandatory)

Never hardcode visual values in widgets. Pull from `ThemeData`, `ColorScheme`, `TextTheme`, and layout tokens (`AppLayout` in `lib/core/theme/app_layout.dart`).

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

## Reference detail

Detail for Color system conventions, Typography conventions, Component theming strategy, Repository layout (`lib/core/theme`): [references/theme-conventions.md](references/theme-conventions.md) — load when touching those areas.

## 2) Light and dark mode parity

Always keep light and dark coherent:

1. Changes go through `MaterialTheme.theme(colorScheme)` or both scheme factories if you edit raw `ColorScheme` constants.
2. Ensure contrast stays readable for text and icons.
3. Verify semantic meaning survives mode switch (error still error, selected still selected).

## 3) Scoped overrides (allowed, but rare)

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

## 4) Review checklist

Before finalizing UI changes, confirm:

- [ ] no hardcoded hex or `Colors.*` in feature widgets
- [ ] no inline `TextStyle(...)` except inside `lib/core/theme` (or font wiring in `App`)
- [ ] spacing/radius uses `AppLayout` (or new tokens in the same file)
- [ ] component defaults live in `MaterialTheme.theme`, not on screens
- [ ] light and dark (and contrast variants if touched) stay visually consistent
- [ ] one-off overrides are scoped to the smallest possible subtree

## 5) Common anti-patterns

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
