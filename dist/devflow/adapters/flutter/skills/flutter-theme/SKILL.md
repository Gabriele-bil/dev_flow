---
name: flutter-theme
description: Use when implementing or refactoring Flutter visual styling (colors, typography, radii, spacing, component themes, light/dark mode). Enforces theme-first UI, semantic Material 3 tokens, and scoped overrides only when unavoidable.
---

# Skill: Flutter Theme

## Purpose

Theme-first styling: every visual value comes from `lib/core/theme` (Material 3 `ColorScheme`, `TextTheme`, component themes, `AppLayout` tokens).

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Constraint, overflow or breakpoint problem → `flutter-layout`
- Loading/skeleton state → `flutter-riverpod`

## Rules

- No hardcoded visual values in feature widgets: no hex, no `Colors.*`, no inline `TextStyle(...)`, no raw radius/spacing literals.
- Read from `Theme.of(context)`: `colorScheme` roles, `textTheme` styles (`copyWith` for one-property tweaks), `AppLayout` tokens (`lib/core/theme/app_layout.dart`).
- Text: `labelLarge` buttons, `title*` titles, `body*` content. Content on colored surfaces uses matching `on*` role, never `Colors.white/black`.
- Component defaults (inputs, buttons, cards, app bar, navigation) defined once in `MaterialTheme.theme(ColorScheme)` — pages only compose widgets.
- Light/dark parity: edit through `MaterialTheme.theme(...)` or both scheme factories; semantic meaning (error, selected) survives mode switch; contrast WCAG AA.
- Non-`ColorScheme` colors (`success`, `warning`, `info`) → `ThemeExtension` or `app_colors.dart` in `lib/core/theme`, never feature constants.
- Scoped override only for one subtree: `Theme(data: Theme.of(context).copyWith(...), child: …)`. Never a page-level override for one widget.

```dart
final colors = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;
Container(color: colors.surface);
Text(t.pets.save, style: text.labelLarge?.copyWith(color: colors.onPrimary));
BorderRadius.circular(AppLayout.inputBorderRadius);
```

`lib/core/theme` layout, color roles, current component themes: [`references/theme-conventions.md`](references/theme-conventions.md).

## Checklist

- [ ] No hex / `Colors.*` / inline `TextStyle` in feature widgets
- [ ] Spacing + radius from `AppLayout` (new token added there if missing)
- [ ] Component defaults in `MaterialTheme.theme`, not on screens
- [ ] Light + dark (and contrast variants if touched) consistent
- [ ] Overrides scoped to smallest subtree

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `*/pages/*.dart`, `*/screens/*.dart`, `*/widgets/*.dart`, `lib/core/theme/**` |
| Reads | `lib/core/theme/`, `constitution.md` (styling conventions) |
| Invoked by | `devflow.plan` (UI introduced), `devflow.implement`, `devflow.beautify` |
| Related skills | `flutter-layout` |
