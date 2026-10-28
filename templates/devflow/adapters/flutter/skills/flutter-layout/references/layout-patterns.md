# Flutter Layout — Code Examples

## Example: Sibling spacing — `spacing:` vs `SizedBox`

**Anti-pattern:** `SizedBox` inserted between every child.

```dart
// BAD
Column(
  children: [
    TitleWidget(),
    SizedBox(height: 8),
    BodyWidget(),
    SizedBox(height: 8),
    FooterWidget(),
  ],
)
```

**Fix:** Single `spacing:` parameter; no extra nodes in the tree.

```dart
// GOOD
Column(
  spacing: 8,
  children: [
    TitleWidget(),
    BodyWidget(),
    FooterWidget(),
  ],
)
```

`SizedBox` remains acceptable for one-off asymmetric gaps (e.g. a larger separator before a footer) where uniform spacing does not apply.

## Example: `ListView` inside `Column` (unbounded height)

**Anti-pattern:** `Column` gives unconstrained height to `ListView`.

```dart
// BAD
Column(
  children: [
    const Text('Header'),
    ListView(
      children: [/* items */],
    ),
  ],
)
```

**Fix:** Constrain list with `Expanded`.

```dart
// GOOD
Column(
  children: [
    const Text('Header'),
    Expanded(
      child: ListView(
        children: [/* items */],
      ),
    ),
  ],
)
```

## Example: Responsive branch with `LayoutBuilder`

Switch structure at a width breakpoint.

```dart
Widget buildAdaptiveLayout(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return Row(
          children: [
            SizedBox(width: 250, child: SidebarWidget()),
            Expanded(child: MainContentWidget()),
          ],
        );
      } else {
        return Column(
          children: [
            Expanded(child: MainContentWidget()),
            BottomNavigationBarWidget(),
          ],
        );
      }
    },
  );
}
```

## Quick Layout Selector

- **Linear horizontal/vertical:** `Row` / `Column`
- **Distribute remaining space:** `Expanded` / `Flexible`
- **Uniform gap between children:** `Row(spacing: ...)` / `Column(spacing: ...)` — **preferred over `SizedBox`**
- **One-off fixed gap (e.g. between sections):** `SizedBox(width/height: ...)` — only when `spacing` cannot apply
- **Padding around content:** `Padding`
- **Decorated box + optional sizing/alignment:** `Container` (only when needed)
- **Overlay elements:** `Stack` + `Positioned`
- **Scrollable list/grid:** `ListView` / `GridView`
- **Single scrollable body:** `SingleChildScrollView` (+ constrained child strategy)
- **React to parent constraints:** `LayoutBuilder`
- **Scale by screen classes:** adaptive branch (for example mobile vs tablet)

## Common Failures and Fast Fixes

- **`RenderFlex overflowed` in `Row`/`Column`:**
  - Wrap expanding child with `Expanded` or reduce fixed-size siblings.
  - For long text, use `Expanded` + `maxLines` + `overflow`.
- **Vertical viewport was given unbounded height (`ListView` in `Column`):**
  - Wrap `ListView` with `Expanded`, or give bounded height via `SizedBox`.
- **Nested scroll conflicts (`ListView` inside `SingleChildScrollView`):**
  - Keep one primary scrollable whenever possible.
  - If unavoidable, use `shrinkWrap: true` + `NeverScrollableScrollPhysics` for inner list (with performance awareness).
- **Unexpected full-width/full-height children:**
  - Inspect parent constraints; remove accidental `double.infinity` sizing in unbounded context.
- **`SizedBox` scattered between every child in a `Row`/`Column`:**
  - Replace all sibling gaps with a single `spacing:` parameter on the parent; remove the `SizedBox` nodes.
- **Inconsistent spacing across screen:**
  - Replace ad-hoc values with consistent spacing tokens/constants.
