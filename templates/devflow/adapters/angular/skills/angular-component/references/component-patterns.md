# Angular Component Patterns

## Table of Contents
- [Model Inputs (Two-Way Binding)](#model-inputs-two-way-binding)
- [View Queries](#view-queries)
- [Content Queries](#content-queries)
- [Dependency Injection in Components](#dependency-injection-in-components)
- [Component Communication Patterns](#component-communication-patterns)
- [Dynamic Components](#dynamic-components)
- [Attribute Directives on Components](#attribute-directives-on-components)
- [Error Boundaries](#error-boundaries)

## Model Inputs (Two-Way Binding)

Use `model()` when component needs `[(value)]` syntax.

```typescript
import { Component, input, model } from '@angular/core';

@Component({
  selector: 'app-slider',
  host: {
    '(input)': 'onInput($event)',
  },
  template: `
    <input
      type="range"
      [value]="value()"
      [min]="min()"
      [max]="max()"
    />
    <span>{{ value() }}</span>
  `,
})
export class Slider {
  // model = input + output pair
  value = model(0);
  min = input(0);
  max = input(100);

  onInput(event: Event) {
    const target = event.target as HTMLInputElement;
    this.value.set(Number(target.value));
  }
}

// Usage: <app-slider [(value)]="sliderValue" />
```

Required model:

```typescript
value = model.required<number>();
```

## View Queries

Query template elements/components with signal query APIs.

```typescript
import { Component, ElementRef, input, viewChild, viewChildren } from '@angular/core';

@Component({
  selector: 'app-gallery',
  template: `
    <div #container class="gallery">
      @for (image of images(); track image.id) {
        <app-image-card [image]="image" />
      }
    </div>
  `,
})
export class Gallery {
  images = input.required<Image[]>();

  // Single element
  container = viewChild.required<ElementRef<HTMLDivElement>>('container');

  // Single component (optional)
  firstCard = viewChild(ImageCard);

  // All matching components
  allCards = viewChildren(ImageCard);
}
```

## Content Queries

Query projected content from parent template.

```typescript
import { Component, contentChild, contentChildren, effect, input, signal } from '@angular/core';

@Component({
  selector: 'app-tabs',
  template: `
    <div class="tab-headers">
      @for (tab of tabs(); track tab.label()) {
        <button
          [class.active]="tab === activeTab()"
          (click)="selectTab(tab)"
        >
          {{ tab.label() }}
        </button>
      }
    </div>
    <div class="tab-content">
      <ng-content />
    </div>
  `,
})
export class Tabs {
  tabs = contentChildren(Tab);
  header = contentChild('tabHeader');

  activeTab = signal<Tab | undefined>(undefined);

  constructor() {
    effect(() => {
      const firstTab = this.tabs()[0];
      if (firstTab && !this.activeTab()) {
        this.activeTab.set(firstTab);
      }
    });
  }

  selectTab(tab: Tab) {
    this.activeTab.set(tab);
  }
}

@Component({
  selector: 'app-tab',
  template: `<ng-content />`,
  host: {
    '[class.active]': 'isActive()',
    '[style.display]': 'isActive() ? "block" : "none"',
  },
})
export class Tab {
  label = input.required<string>();
  isActive = input(false);
}
```

## Dependency Injection in Components

Prefer `inject()` over constructor DI.

```typescript
import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-dashboard',
  template: `...`,
})
export class Dashboard {
  private router = inject(Router);
  private userService = inject(UserService);
  private config = inject(APP_CONFIG);

  // Optional dependency
  private analytics = inject(AnalyticsService, { optional: true });

  // Resolve from current injector only
  private localService = inject(LocalService, { self: true });

  navigateToProfile() {
    this.router.navigate(['/profile']);
  }
}
```

## Component Communication Patterns

### Parent to Child (Inputs)

```typescript
// Parent
@Component({
  template: `<app-child [data]="parentData()" [config]="config" />`,
})
export class Parent {
  parentData = signal({ name: 'Test' });
  config = { theme: 'dark' };
}

// Child
@Component({ selector: 'app-child' })
export class Child {
  data = input.required<Data>();
  config = input<Config>();
}
```

### Child to Parent (Outputs)

```typescript
// Child
@Component({
  selector: 'app-child',
  template: `<button (click)="save()">Save</button>`,
})
export class Child {
  saved = output<Data>();

  save() {
    this.saved.emit({ id: 1, name: 'Item' });
  }
}

// Parent
@Component({
  template: `<app-child (saved)="onSaved($event)" />`,
})
export class Parent {
  onSaved(data: Data) {
    console.log('Saved:', data);
  }
}
```

### Shared Service Pattern

```typescript
import { Injectable, computed, inject, input, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class CartService {
  private items = signal<CartItem[]>([]);

  readonly itemsReadonly = this.items.asReadonly();
  readonly total = computed(() =>
    this.items().reduce((sum, item) => sum + item.price, 0)
  );

  addItem(item: CartItem) {
    this.items.update(items => [...items, item]);
  }

  removeItem(id: string) {
    this.items.update(items => items.filter(i => i.id !== id));
  }
}

@Component({ template: `<button (click)="add()">Add</button>` })
export class ProductCard {
  private cart = inject(CartService);
  product = input.required<Product>();

  add() {
    this.cart.addItem({ ...this.product(), quantity: 1 });
  }
}

@Component({ template: `<span>Total: {{ cart.total() }}</span>` })
export class CartSummary {
  cart = inject(CartService);
}
```

## Dynamic Components

Use `@defer` for lazy render/lazy load paths.

```typescript
@Component({
  template: `
    @defer (on viewport) {
      <app-heavy-chart [data]="chartData()" />
    } @placeholder {
      <div class="chart-placeholder">Loading chart...</div>
    } @loading (minimum 500ms) {
      <app-spinner />
    } @error {
      <p>Failed to load chart</p>
    }
  `,
})
export class Dashboard {
  chartData = input.required<ChartData>();
}
```

Defer triggers:
- `on viewport` - enter viewport
- `on idle` - browser idle
- `on interaction` - click/focus
- `on hover` - mouse hover
- `on immediate` - right after non-deferred
- `on timer(500ms)` - after delay
- `when condition` - expression true

```typescript
@Component({
  template: `
    @defer (on interaction; prefetch on idle) {
      <app-comments [postId]="postId()" />
    } @placeholder {
      <button>Load Comments</button>
    }
  `,
})
export class PostView {
  postId = input.required<string>();
}
```

## Attribute Directives on Components

```typescript
import { Directive, input } from '@angular/core';

@Directive({
  selector: '[appHighlight]',
  host: {
    '[style.backgroundColor]': 'color()',
  },
})
export class HighlightDirective {
  color = input('yellow', { alias: 'appHighlight' });
}

// Usage on component
@Component({
  imports: [HighlightDirective],
  template: `<app-card appHighlight="lightblue" />`,
})
export class Page {}
```

## Error Boundaries

Wrap unstable subtree with local fallback UI.

```typescript
import { Component, ErrorHandler, inject, signal } from '@angular/core';

@Component({
  selector: 'app-error-boundary',
  template: `
    @if (hasError()) {
      <div class="error">
        <h3>Something went wrong</h3>
        <button (click)="retry()">Retry</button>
      </div>
    } @else {
      <ng-content />
    }
  `,
})
export class ErrorBoundary {
  hasError = signal(false);
  private errorHandler = inject(ErrorHandler);

  retry() {
    this.hasError.set(false);
  }
}
```
