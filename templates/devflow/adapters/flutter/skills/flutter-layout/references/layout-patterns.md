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
