# Angular Aria — project decisions

Loaded on demand from `../SKILL.md`. `@angular/aria` is young and its inputs still change between minors: check current docs with Context7 (`/websites/angular_dev` "aria <widget>") before writing any widget — the angular.dev guide has a full example per widget.

## Widget choice

| Need | Widget | Avoid when |
| --- | --- | --- |
| Visible single/multi-select list | Listbox | dropdown needed → Combobox |
| Typing filters options | Combobox on `<input>` | fixed short list → Select |
| Choose from closed list | Combobox on `<div>`/`<button>` (Select) | — |
| Collapsible sections | Accordion | primary navigation; sections read side by side |
| Switch between related panels | Tabs | sequential steps (stepper); > 7–8 tabs |
| Command bar / context menu | Menu, MenuBar | simple action list on mobile |
| Grouped controls (formatting) | Toolbar | — |
| Hierarchy (files, org chart) | Tree | flat list |
| 2D keyboard navigation (data table, calendar) | Grid | read-only table → plain `<table>` |

## Combobox (verified shape)

```html
<input ngCombobox #combobox="ngCombobox" [(value)]="query" [(expanded)]="open" />

<ng-template [cdkConnectedOverlay]="{ origin, usePopover: 'inline', matchWidth: true }" [cdkConnectedOverlayOpen]="open()">
  <ng-template ngComboboxPopup [combobox]="combobox">
    <div ngListbox ngComboboxWidget #listbox="ngListbox" focusMode="activedescendant"
         [activeDescendant]="listbox.activeDescendant()" [(value)]="selected">
      @for (c of options(); track c) { <div ngOption [value]="c" [label]="c">{{ c }}</div> }
    </div>
  </ng-template>
</ng-template>
```

- Popup positioning: CDK Overlay (`@angular/cdk/overlay`), not hand-written absolute CSS.
- Add an `aria-live="polite"` region for "no results".

## Forms

Wrap the widget in a component implementing `FormValueControl<T>` (`value = model<T>()`, `touched`/`invalid`/`errors` inputs, `touch` output) and bind `[formField]` on the wrapper. Rules (`required`, …) stay in the form schema (`angular-forms`).

## Lazy content

Heavy panels inside `<ng-template>` with the content directive (`ngAccordionContent`, `ngTabContent`, `ngMenuContent`, `ngComboboxPopup`, `ngTreeItemGroup`) — rendered only when opened.

## Testing

Assert ARIA state, not structure: `aria-expanded`, `aria-selected`, focus after arrow keys. Use the package harnesses when the widget ships one (check docs), else a project `ComponentHarness` (`angular-testing`).
