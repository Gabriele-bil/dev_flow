---
name: "flutter-layout"
description: "Use when implementing or fixing Flutter widget layouts, especially with overflows, unbounded constraints, nested scrollables, alignment issues, or responsive/adaptive breakpoints."
argument-hint: [optional-plan-path]
---

# Writing Correct Flutter Layouts

## Overview

Build Flutter layouts that are constraint-safe, responsive, evolvable.

Full code examples: `references/layout-patterns.md`.

## Core Layout Principles

Core Flutter rule: **Constraints go down. Sizes go up. Parent sets position.**

- **Pass constraints down:** Children must pick a size inside parent bounds.
- **Pass sizes up:** Parent positions children after they report size.
- **Parent sets position:** Children do not choose their own offset.
- **Avoid unbounded constraints:** Most runtime layout errors come from this.
- **One primary scroll direction per region:** Nesting scrollables without bounds causes broken layouts.

## When to Use

- Building new UI screens or reusable widgets.
- Refactoring deeply nested `Row`/`Column` trees.
- Fixing `RenderFlex overflowed`, "unbounded constraints", clipped content, or inconsistent spacing.
- Implementing responsive or adaptive behavior for phone/tablet/desktop.

## Reference detail

Detail for Quick Layout Selector, Common Failures and Fast Fixes: [references/layout-patterns.md](references/layout-patterns.md) — load when touching those areas.

## Workflow (Constraint-First)

### 1) Decompose the UI

- Split the screen into sections: header, body, footer, overlays.
- Decide which section scrolls and which remains fixed.
- Mark fixed-size vs flexible-size areas.

### 2) Model constraints before coding

- For each section, define max/min width/height expectations.
- In `Row`/`Column`, decide which children must flex (`Expanded`) and which stay intrinsic.
- Identify risky spots: scrollables in flex layouts, unconstrained text/images, nested scrollables.

### 3) Implement outer-to-inner

- Start with high-level structure (`Scaffold`, page sections).
- Add uniform spacing between siblings via `Row(spacing:)` / `Column(spacing:)`; use `SizedBox` only for isolated gaps or section separators.
- Extract repeated or deep subtrees into private stateless widgets.

### 4) Validate with tools and edge cases

- Use Flutter Inspector and enable debug paint when needed.
- Test with tiny and very large widths, text scale, and dynamic content lengths.
- Confirm there are no overflow stripes or layout exceptions.

## Responsive vs Adaptive

- **Responsive:** Same widget tree adapts with available constraints (`Expanded`, `Flexible`, `Wrap`, `LayoutBuilder`).
- **Adaptive:** Different widget tree by form factor (for example bottom nav on mobile, `NavigationRail` on wide layouts).

## Layout Quality Checklist (Definition of Done)

- [ ] No layout exceptions in debug console.
- [ ] No overflow warnings on target breakpoints.
- [ ] Scroll behavior is intentional and predictable.
- [ ] Long text, larger accessibility font, and dynamic data do not break structure.
- [ ] Spacing and alignment are consistent with design tokens.
- [ ] Widget tree is readable (large sections extracted into subwidgets).

## Examples

Sibling spacing (`spacing:` vs `SizedBox`), `ListView` inside `Column` fix, responsive `LayoutBuilder` branch → `references/layout-patterns.md`.

## I/O Reference

|                |                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------ |
| Trigger        | Any layout overflow, unbounded constraint error, or responsive/adaptive breakpoint work                      |
| Reads          | `lib/core/layout/app_breakpoints.dart` (`AppBreakpointWidth`, `AppBreakpointConstraints`), `constitution.md` |
| Invoked by     | `devflow.implement` (all UI screens), `devflow.beautify` (layout area E — responsive layout)                 |
| Related skills | `flutter-theme` (spacing and sizing tokens)                                                                  |
