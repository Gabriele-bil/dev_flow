# Angular Aria — Widget Patterns

## Accordion

```html
<div ngAccordionGroup [multiExpandable]="false">
  <div class="accordion-item">
    <button ngAccordionTrigger [panel]="panel1" class="accordion-header">
      Section 1
      <span class="icon">▼</span>
    </button>
    <div ngAccordionPanel #panel1="ngAccordionPanel" class="accordion-panel">
      <ng-template ngAccordionContent>
        <p>Lazy loaded content here.</p>
      </ng-template>
    </div>
  </div>
</div>
```

```css
.accordion-header[aria-expanded="true"] .icon { transform: rotate(180deg); }
.accordion-panel { padding: 1rem; border-top: 1px solid #ccc; }
```

Use for FAQs, long forms, progressive disclosure. Avoid for primary navigation or when users must view multiple sections simultaneously.

## Listbox

```html
<ul ngListbox [(value)]="selectedItems" orientation="horizontal" [multi]="true">
  <li ngOption value="apple" class="option">Apple</li>
  <li ngOption value="banana" class="option">Banana</li>
</ul>
```

```css
.option[aria-selected="true"] { background: #e0f7fa; font-weight: bold; }
.option:focus-visible { outline: 2px solid blue; }
```

Use for visible single/multi-select lists — not dropdowns (use Combobox/Select for those).

## Combobox / Select / Multiselect

Combine `ngCombobox` (trigger) with `ngListbox` (popup). Combobox = `<input ngCombobox>` (typing filters). Select = `<div ngCombobox>`/`<button ngCombobox>` (choose from list). Multiselect = either + multi-select `ngListbox`.

```html
<!-- Autocomplete -->
<div>
  <input
    ngCombobox
    #combobox="ngCombobox"
    [(value)]="searchString"
    [(expanded)]="isExpanded"
    placeholder="Search options..."
    class="select-trigger"
  />

  <ng-template ngComboboxPopup [combobox]="combobox">
    <ul
      ngComboboxWidget
      ngListbox
      #listbox="ngListbox"
      [(value)]="selectedValue"
      [activeDescendant]="listbox.activeDescendant()"
      class="dropdown-menu"
    >
      <li ngOption value="option1" label="Option 1" class="option">Option 1</li>
      <li ngOption value="option2" label="Option 2" class="option">Option 2</li>
    </ul>
  </ng-template>
</div>

<!-- Select (focusable div trigger) -->
<div ngCombobox #select="ngCombobox" [(expanded)]="selectExpanded" class="select-trigger">
  <span class="select-text">{{ selectedValue() ?? "Choose an option" }}</span>
  <span class="icon">▼</span>
</div>

<ng-template ngComboboxPopup [combobox]="select">
  <ul
    ngComboboxWidget
    ngListbox
    #selectListbox="ngListbox"
    [(value)]="selectedValues"
    [activeDescendant]="selectListbox.activeDescendant()"
    (click)="onCommit()"
    (keydown.enter)="onCommit()"
    class="dropdown-menu"
  >
    <li ngOption value="option1" label="Option 1" class="option">Option 1</li>
    <li ngOption value="option2" label="Option 2" class="option">Option 2</li>
  </ul>
</ng-template>
```

```css
.select-trigger { width: 200px; padding: 8px; text-align: left; }
.dropdown-menu { list-style: none; padding: 0; margin: 0; border: 1px solid #ccc; background: white; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); }
```

Pair popup with CDK Overlay for floating positioning.

## Menu / Menubar

```html
<div ngMenuBar class="menubar">
  <div ngMenuItem value="file" [submenu]="fileMenu" class="menubar-item">File</div>
  <div ngMenuItem value="edit" [submenu]="editMenu" class="menubar-item">Edit</div>
</div>

<div ngMenu #fileMenu="ngMenu" class="menu">
  <ng-template ngMenuContent>
    <div ngMenuItem value="new">New</div>
    <div ngMenuItem value="open">Open</div>
  </ng-template>
</div>

<div ngMenu #editMenu="ngMenu" class="menu">
  <ng-template ngMenuContent>
    <div ngMenuItem value="cut">Cut</div>
    <div ngMenuItem value="copy">Copy</div>
  </ng-template>
</div>
```

```css
.menubar { display: flex; gap: 10px; list-style: none; padding: 0; }
.menu { background: white; border: 1px solid #ccc; padding: 5px 0; }
.menu li { padding: 5px 15px; cursor: pointer; }
```

Menubar = persistent desktop-style command bars with full horizontal keyboard support. Avoid for simple action lists or constrained mobile layouts.

## Tabs

```html
<div ngTabs>
  <ul ngTabList [(selectedTab)]="selectedTabValue" class="tab-list">
    <li ngTab value="profile" class="tab-btn">Profile</li>
    <li ngTab value="security" class="tab-btn">Security</li>
  </ul>

  <div ngTabPanel value="profile" class="tab-panel">
    <ng-template ngTabContent>Profile Settings</ng-template>
  </div>
  <div ngTabPanel value="security" class="tab-panel">
    <ng-template ngTabContent>Security Settings</ng-template>
  </div>
</div>
```

```css
.tab-list { display: flex; border-bottom: 2px solid #ccc; list-style: none; padding: 0; }
.tab-btn { padding: 10px 20px; cursor: pointer; border-bottom: 2px solid transparent; }
.tab-btn[aria-selected="true"] { border-bottom-color: blue; font-weight: bold; }
.tab-panel { padding: 20px; }
```

Use for related content sections users switch between. Avoid for sequential workflows (steppers) or >7-8 sections.

## Toolbar

```html
<div ngToolbar class="toolbar">
  <div ngToolbarWidgetGroup [multi]="true" role="group" aria-label="Formatting">
    <button ngToolbarWidget value="bold" class="tool-btn">B</button>
    <button ngToolbarWidget value="italic" class="tool-btn">I</button>
  </div>
</div>
```

```css
.toolbar { display: flex; gap: 5px; padding: 8px; background: #f5f5f5; }
.tool-btn[aria-pressed="true"],
.tool-btn[aria-checked="true"] { background: #ddd; }
```

Groups frequently-used related controls (text formatting, media controls) — boosts keyboard efficiency via arrow-key navigation.

## Tree

```html
<ul ngTree #tree="ngTree" [(value)]="selectedValues" class="tree">
  <li ngTreeItem [parent]="tree" value="documents" #docsItem="ngTreeItem">
    <span class="tree-label">Documents</span>
    <ul role="group">
      <ng-template ngTreeItemGroup [ownedBy]="docsItem" #docsGroup="ngTreeItemGroup">
        <li ngTreeItem [parent]="docsGroup" value="resume">Resume.pdf</li>
        <li ngTreeItem [parent]="docsGroup" value="cover-letter">CoverLetter.pdf</li>
      </ng-template>
    </ul>
  </li>
</ul>
```

```css
.tree, .tree-group { list-style: none; padding-left: 20px; }
.tree-label::before { content: "▶ "; display: inline-block; transition: transform 0.2s; }
li[aria-expanded="true"] > .tree-label::before { transform: rotate(90deg); }
```

For deeply nested hierarchical data (file systems, org charts). Avoid for flat lists or simple selection menus.

## Grid

```html
<table ngGrid [multi]="true" [enableSelection]="true" class="grid-table">
  <tr ngGridRow>
    <th ngGridCell role="columnheader">Name</th>
    <th ngGridCell role="columnheader">Status</th>
  </tr>
  <tr ngGridRow>
    <td ngGridCell>Project A</td>
    <td ngGridCell [(selected)]="isSelected">
      <button ngGridCellWidget (activated)="onActivate()">Active</button>
    </td>
  </tr>
</table>
```

```css
.grid-table { border-collapse: collapse; }
[ngGridCell] { padding: 8px; border: 1px solid #ddd; }
[ngGridCell][aria-selected="true"] { background: #e3f2fd; }
[ngGridCell]:focus-visible { outline: 2px solid #2196f3; outline-offset: -2px; }
```

For data tables, calendars, spreadsheets — 2D arrow-key navigation.

## Signal Forms Binding — Combobox/Select Inside a Form

`[formField]` auto-detects `ngCombobox`/`ngListbox` as custom controls (they expose `value` model).

```typescript
protected readonly citySignal = signal({ name: "", city: "" });
protected readonly myForm = form(this.citySignal, schema((f) => {
  required(f.city);
}));
```

```html
<!-- Combobox bound to formField -->
<input
  ngCombobox
  #combobox="ngCombobox"
  [formField]="myForm.city"
  [(expanded)]="isExpanded"
  placeholder="Search cities..."
/>

<ng-template ngComboboxPopup [combobox]="combobox">
  <ul ngComboboxWidget ngListbox #listbox="ngListbox" [(value)]="selectedValue"
      [activeDescendant]="listbox.activeDescendant()" class="dropdown-menu">
    <li ngOption value="sfo" label="San Francisco">San Francisco</li>
    <li ngOption value="nyc" label="New York">New York</li>
  </ul>
</ng-template>

<!-- Select trigger bound to formField -->
<div
  ngCombobox
  #select="ngCombobox"
  [formField]="myForm.city"
  [(expanded)]="isExpanded"
  class="select-trigger"
>
  <span class="select-text">{{ myForm.city.value() || "Choose your city" }}</span>
  <span class="icon">▼</span>
</div>

<!-- Multi-select listbox bound directly to a form array -->
<ul ngListbox [formField]="myForm.interests" [multi]="true" class="interest-list">
  <li ngOption value="sports">Sports</li>
  <li ngOption value="music">Music</li>
  <li ngOption value="tech">Technology</li>
</ul>
```

Always pair `[formField]` with `schema()` validation rules (`required`, etc.) — see `angular-forms`.
