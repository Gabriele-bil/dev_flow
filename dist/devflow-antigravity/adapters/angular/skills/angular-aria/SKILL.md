---
name: angular-aria
description: Angular v22+ accessible widgets (Accordion, Listbox, Combobox, Menu, Tabs, Tree, Grid) via `@angular/aria` headless directives. Use for keyboard-navigable ARIA components. Triggers on `ngListbox`, `ngCombobox`, `ngMenu`, `ngTabs`, `ngTree`, `ngGrid` imports.
---

# Angular Aria

## Purpose

Build accessible composite widgets with `@angular/aria` headless directives: they own keyboard interaction, ARIA attributes and focus; the project owns markup and CSS.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix (no `@angular/aria` import, no composite widget touched).
- Simple controls with a native element (`<button>`, checkbox, radio, text input) — native HTML, `angular-component` accessibility baseline.
- Form rules for the widget value → `angular-forms`.

## Setup

`@angular/aria` is installed by `devflow.setup` (`steps/setup.md`). Missing in an older project → `pnpm add @angular/aria`.

## Directive Families

| Widget | Import path | Directives |
|---|---|---|
| Accordion | `@angular/aria/accordion` | `ngAccordionGroup`, `ngAccordionTrigger`, `ngAccordionPanel`, `ngAccordionContent` |
| Listbox | `@angular/aria/listbox` | `ngListbox`, `ngOption` |
| Combobox | `@angular/aria/combobox` | `ngCombobox`, `ngComboboxPopup`, `ngComboboxWidget` (+ `ngListbox`) |
| Menu | `@angular/aria/menu` | `ngMenuBar`, `ngMenu`, `ngMenuItem`, `ngMenuTrigger`, `ngMenuContent` |
| Tabs | `@angular/aria/tabs` | `ngTabs`, `ngTabList`, `ngTab`, `ngTabPanel`, `ngTabContent` |
| Toolbar | `@angular/aria/toolbar` | `ngToolbar`, `ngToolbarWidget`, `ngToolbarWidgetGroup` |
| Tree | `@angular/aria/tree` | `ngTree`, `ngTreeItem`, `ngTreeItemGroup` |
| Grid | `@angular/aria/grid` | `ngGrid`, `ngGridRow`, `ngGridCell`, `ngGridCellWidget` |

## Hard Rules

- Custom select/autocomplete/menu/tabs/tree → `ng*` directives. Do not use native `<select>`/`<input list>`/`<details>` for these patterns — they cannot express the interaction model.
- Headless = you style it: every widget gets CSS for its state attributes (`[aria-selected="true"]`, `[aria-expanded="true"]`, `[aria-disabled]`, `:focus-visible`). Unstyled state = visually broken.
- Colors from theme tokens via `angular-theme` conventions — no hardcoded hex.
- Heavy panel content inside `<ng-template>` with the matching `ng*Content`/`ng*Group` directive (lazy).
- Inside forms: wrap the widget in a `FormValueControl` component, bind `[formField]` on the wrapper.

```html
<ul ngListbox [(value)]="selected" [multi]="true">
  <li ngOption value="apple" class="option">Apple</li>
  <li ngOption value="banana" class="option">Banana</li>
</ul>
```

```css
.option[aria-selected="true"] { @apply bg-primary-100 font-semibold; }
.option:focus-visible { @apply outline-2 outline-primary-600; }
```

Widget choice table, Combobox + CDK Overlay shape, form wrapper, testing: [references/aria-patterns.md](references/aria-patterns.md). Check current docs with Context7 before writing widget inputs.

## I/O Reference

|            |                                                                   |
| ---------- | ----------------------------------------------------------------- |
| Reads      | Active component/template files, `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/angular/ADAPTER.md` |
| Writes     | New or refactored accessible widget components, styles, harness tests |
| Invoked by | `devflow.implement`, `devflow.beautify`                           |
