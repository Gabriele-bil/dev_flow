---
name: flutter-layout
description: Use when implementing or fixing Flutter widget layouts, especially with overflows, unbounded constraints, nested scrollables, alignment issues, or responsive/adaptive breakpoints.
---

# Skill: Flutter Layout

## Purpose

Constraint-safe, responsive layouts on project breakpoints (`AppBreakpointWidth` / `AppBreakpointConstraints`), one scroll owner per region, token spacing.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Colors, typography, component styling → `flutter-theme`
- Loading/skeleton rendering → `flutter-riverpod`

## Rules

- **Breakpoints:** branch with `LayoutBuilder` + `AppBreakpointConstraints` (on `BoxConstraints`) or `AppBreakpointWidth` (on `double`) from `lib/core/layout/app_breakpoints.dart` (or the path in `constitution.md`). No width literals (`> 600`) in features. Every new screen covers compact / medium / expanded.
- **Responsive vs adaptive:** same tree flexing (`Expanded`, `Flexible`, `Wrap`) when content only reflows; different tree (bottom nav ↔ `NavigationRail`) when navigation or density changes.
- **Sibling spacing:** `Row(spacing:)` / `Column(spacing:)` with `AppLayout` tokens. `SizedBox` only for one-off asymmetric gaps — never between every child.
- **Scrolling:** one primary scrollable per region. Scrollable inside `Column`/`Row` → wrap in `Expanded` (or bounded `SizedBox`). Nested scrollables avoided; when unavoidable, inner list `shrinkWrap: true` + `NeverScrollableScrollPhysics`, short lists only.
- **Large lists:** `ListView.builder` / slivers, never `ListView(children: [...])` over unbounded data.
- **Overflow:** long text in a `Row` → `Expanded` + `maxLines` + `overflow`; no `double.infinity` inside unbounded parents.
- **Structure:** build outer → inner (`Scaffold`, sections, then content); extract deep or repeated subtrees into private `StatelessWidget`s, not helper methods returning widgets.
- Layout primitives and error explanations: Flutter docs via Dart MCP / Context7 (`/flutter/website`) — not repeated here.

## Checklist

- [ ] No overflow stripes or layout exceptions at compact / medium / expanded
- [ ] Large text scale (≥1.5) and long content do not break structure
- [ ] Spacing via `spacing:` + `AppLayout` tokens
- [ ] Breakpoint tests size the view (`steps/test.md` → Responsive tests)

## I/O Reference

| | |
| --- | --- |
| Trigger | `steps/implement.md` matrix row: `*/pages/*.dart`, `*/screens/*.dart`, `*/widgets/*.dart`, `lib/core/layout/**`, overflow fix |
| Reads | `lib/core/layout/app_breakpoints.dart`, `constitution.md` |
| Invoked by | `devflow.implement` (UI screens), `devflow.beautify` (responsive layout axis) |
| Related skills | `flutter-theme` (spacing + sizing tokens) |
