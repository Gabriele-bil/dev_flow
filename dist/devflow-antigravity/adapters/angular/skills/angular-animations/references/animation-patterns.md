# Angular Animations — reference detail

Loaded on demand from `../SKILL.md`.

## Legacy DSL (`@angular/animations`) — Pre-v20.2 / Heavy Existing Usage Only

```typescript
bootstrapApplication(App, { providers: [provideAnimationsAsync()] });
```

```typescript
import { trigger, state, style, animate, transition } from "@angular/animations";

@Component({
  animations: [
    trigger("openClose", [
      state("open", style({ opacity: 1 })),
      state("closed", style({ opacity: 0 })),
      transition("open <=> closed", [animate("0.5s")]),
    ]),
  ],
  template: `<div [@openClose]="isOpen() ? 'open' : 'closed'">...</div>`,
})
export class OpenClose {
  protected readonly isOpen = signal(true);
}
```

**Never mix legacy DSL and `animate.enter`/`animate.leave` in the same component** — conflicting animation systems produce undefined timing behavior.
