---
name: angular-aria
description: Build accessible custom widgets (Accordion, Listbox, Combobox, Select, Menu, Tabs, Toolbar, Tree, Grid) with Angular Aria headless directives for v22+. Use when implementing keyboard-navigable, ARIA-compliant interactive components instead of native form controls. Triggers on custom-widget creation, accessibility requirements, or `ng*` Aria directive imports (`ngListbox`, `ngCombobox`, `ngMenu`, `ngTabs`, `ngTree`, `ngGrid`, etc.).
---

# Angular Aria

Build accessible interactive widgets with `@angular/aria` headless directives. They handle keyboard interaction, ARIA attributes, focus management, screen-reader support — you provide HTML structure + CSS.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Setup

```bash
npm install @angular/aria
```

Confirm install before use — package not present by default.

## Headless = You Style It

Directives ship zero CSS. Style by targeting the ARIA attributes/state the directives toggle automatically:

```css
.option[aria-selected="true"] { background: #e0f7fa; font-weight: bold; }
.tab-btn[aria-selected="true"] { border-bottom-color: blue; }
.accordion-header[aria-expanded="true"] .icon { transform: rotate(180deg); }
.tool-btn[aria-pressed="true"] { background: #ddd; }
li[aria-expanded="true"] > .tree-label::before { transform: rotate(90deg); }
[ngGridCell]:focus-visible { outline: 2px solid #2196f3; outline-offset: -2px; }
```

Common targets: `[aria-expanded]`, `[aria-selected]`, `[aria-disabled]`, `[aria-current]`, `[aria-pressed]`, `[aria-checked]`, `:focus-visible`.

## Directive Families

| Widget | Import path | Directives | Use for |
|---|---|---|---| |
| Accordion | `@angular/aria/accordion` | `ngAccordionGroup`, `ngAccordionTrigger`, `ngAccordionPanel`, `ngAccordionContent` | FAQs, progressive disclosure | |
| Listbox | `@angular/aria/listbox` | `ngListbox`, `ngOption` | Visible single/multi-select lists | |
| Combobox | `@angular/aria/combobox` | `ngCombobox`, `ngComboboxPopup`, `ngComboboxWidget` | Autocomplete, Select, Multiselect (paired w/ `ngListbox`) | |
| Menu | `@angular/aria/menu` | `ngMenuBar`, `ngMenu`, `ngMenuItem`, `ngMenuTrigger`, `ngMenuContent` | Command bars, context menus | |
| Tabs | `@angular/aria/tabs` | `ngTabs`, `ngTabList`, `ngTab`, `ngTabPanel`, `ngTabContent` | Layered content sections | |
| Toolbar | `@angular/aria/toolbar` | `ngToolbar`, `ngToolbarWidget`, `ngToolbarWidgetGroup` | Grouped related controls | |
| Tree | `@angular/aria/tree` | `ngTree`, `ngTreeItem`, `ngTreeItemGroup` | Hierarchical/nested data | |
| Grid | `@angular/aria/grid` | `ngGrid`, `ngGridRow`, `ngGridCell`, `ngGridCellWidget` | 2D interactive collections (tables, calendars) | |

Full HTML/CSS examples per widget: [references/aria-patterns.md](references/aria-patterns.md).

## Quick Example — Listbox

```html
<ul ngListbox [(value)]="selectedItems" orientation="vertical" [multi]="true">
  <li ngOption value="apple" class="option">Apple</li>
  <li ngOption value="banana" class="option">Banana</li>
</ul>
```

```css
.option[aria-selected="true"] { background: #e0f7fa; font-weight: bold; }
.option:focus-visible { outline: 2px solid blue; }
```

## Lazy-Loaded Content

Use structural content directives inside `<ng-template>` for heavy panels — defers rendering until needed:

```html
<div ngAccordionPanel #panel="ngAccordionPanel">
  <ng-template ngAccordionContent>
    <p>Lazy-loaded content here.</p>
  </ng-template>
</div>
```

Applies to `ngAccordionContent`, `ngTabContent`, `ngMenuContent`, `ngComboboxPopup`, `ngTreeItemGroup`.

## Signal Forms Integration

Aria directives expose `model()`-based `value` — `[formField]` binds them as custom controls out-of-the-box.

```html
<ul ngListbox [formField]="myForm.interests" [multi]="true">
  <li ngOption value="sports">Sports</li>
  <li ngOption value="music">Music</li>
</ul>
```

See `angular-forms` for schema/model conventions. See [references/aria-patterns.md](references/aria-patterns.md) for Combobox/Select form-binding examples.

## Testing with Harnesses

Built on `@angular/cdk/testing` — assert behavior, not DOM structure.

```typescript
import { TestbedHarnessEnvironment } from "@angular/cdk/testing/testbed";
import { AccordionHarness } from "@angular/aria/accordion/testing";

const loader = TestbedHarnessEnvironment.loader(fixture);
const accordion = await loader.getHarness(AccordionHarness.with({ title: "Section 1" }));

expect(await accordion.isExpanded()).toBeFalse();
await accordion.expand();
expect(await accordion.isExpanded()).toBeTrue();
```

See `angular-testing` for harness setup conventions shared across the codebase.

## Hard Rules

- Never use native `<select>`/`<input list>`/`<details>` for these patterns — use `ng*` directives. Native elements can't express these interaction models accessibly.
- Always provide CSS for ARIA-state selectors — directives apply attributes, not styles. Unstyled = visually broken, not just unstyled.
- Lazy-load heavy panel content via the `ng*Content`/`ng*Group` structural directives in `<ng-template>`.
- Style via `angular-theme` conventions (`@apply` against ARIA-attribute selectors) — keep widget CSS colocated with the component.

## I/O Reference

|            |                                                                   | |
| ---------- | ----------------------------------------------------------------- | |
| Reads      | Active component/template files, `@devflow/adapters/angular/ADAPTER.md` | |
| Writes     | New or refactored accessible widget components, styles, harness tests | |
| Invoked by | `devflow.implement`, `devflow.beautify`                           | |
