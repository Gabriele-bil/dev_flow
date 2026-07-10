# Angular Signal Forms Patterns

Advanced patterns for `@angular/forms/signals` only.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Form Models](#form-models)
- [Field State](#field-state)
- [Validation](#validation)
- [Conditional Fields](#conditional-fields)
- [Form Submission](#form-submission)
- [Arrays and Dynamic Fields](#arrays-and-dynamic-fields)
- [Displaying Errors](#displaying-errors)
- [Styling Based on State](#styling-based-on-state)
- [Reset Form](#reset-form)
- [Strict Rules & Common Pitfalls](#strict-rules--common-pitfalls)
- [Multi-Step Wizard](#multi-step-wizard)
- [Schema-Driven Dynamic Fields](#schema-driven-dynamic-fields)
- [Async Validation with Debounce and Stale Response Guard](#async-validation-with-debounce-and-stale-response-guard)
- [Form Performance Patterns](#form-performance-patterns)
- [Testing Strategy](#testing-strategy)

## Basic Setup

```typescript
import { Component, signal } from "@angular/core";
import { form, FormField, required, email } from "@angular/forms/signals";

interface LoginData {
  email: string;
  password: string;
}

@Component({
  selector: "app-login",
  imports: [FormField],
  template: `
    <form (submit)="onSubmit($event)">
      <label>
        Email
        <input type="email" [formField]="loginForm.email" />
      </label>
      @if (loginForm.email().touched() && loginForm.email().invalid()) {
        <p class="error">{{ loginForm.email().errors()[0].message }}</p>
      }

      <label>
        Password
        <input type="password" [formField]="loginForm.password" />
      </label>
      @if (loginForm.password().touched() && loginForm.password().invalid()) {
        <p class="error">{{ loginForm.password().errors()[0].message }}</p>
      }

      <button type="submit" [disabled]="loginForm().invalid()">Login</button>
    </form>
  `,
})
export class Login {
  // Writable model signal
  loginModel = signal<LoginData>({
    email: "",
    password: "",
  });

  // Form schema + validators
  loginForm = form(this.loginModel, (schemaPath) => {
    required(schemaPath.email, { message: "Email is required" });
    email(schemaPath.email, { message: "Enter a valid email address" });
    required(schemaPath.password, { message: "Password is required" });
  });

  onSubmit(event: Event) {
    event.preventDefault();
    if (this.loginForm().valid()) {
      const credentials = this.loginModel();
      console.log("Submitting:", credentials);
    }
  }
}
```

## Form Models

```typescript
interface UserProfile {
  name: string;
  email: string;
  age: number | null;
  preferences: {
    newsletter: boolean;
    theme: "light" | "dark";
  };
}

const userModel = signal<UserProfile>({
  name: "",
  email: "",
  age: null,
  preferences: {
    newsletter: false,
    theme: "light",
  },
});

const userForm = form(userModel);

// Nested access
userForm.name;
userForm.preferences.theme;
```

### Reading Values

```typescript
const data = this.userModel();

const name = this.userForm.name().value();
const theme = this.userForm.preferences.theme().value();
```

### Updating Values

```typescript
this.userModel.set({
  name: "Alice",
  email: "alice@example.com",
  age: 30,
  preferences: { newsletter: true, theme: "dark" },
});

this.userForm.name().value.set("Bob");
this.userForm.age().value.update((age) => (age ?? 0) + 1);
```

## Field State

Each field exposes reactive state signals.

```typescript
const emailField = this.form.email();

// Validation
emailField.valid();
emailField.invalid();
emailField.errors();
emailField.pending();

// Interaction
emailField.touched();
emailField.dirty();

// Availability
emailField.disabled();
emailField.hidden();
emailField.readonly();

// Value signal
emailField.value();
```

### Form-Level State

```typescript
this.form().valid();
this.form().touched();
this.form().dirty();
```

## Validation

### Built-in Validators

```typescript
import {
  form,
  required,
  email,
  min,
  max,
  minLength,
  maxLength,
  pattern,
} from "@angular/forms/signals";

const userForm = form(this.userModel, (schemaPath) => {
  required(schemaPath.name, { message: "Name is required" });
  email(schemaPath.email, { message: "Invalid email" });
  min(schemaPath.age, 18, { message: "Must be 18+" });
  max(schemaPath.age, 120, { message: "Invalid age" });
  minLength(schemaPath.password, 8, { message: "Min 8 characters" });
  maxLength(schemaPath.bio, 500, { message: "Max 500 characters" });
  pattern(schemaPath.phone, /^\d{3}-\d{3}-\d{4}$/, {
    message: "Format: 555-123-4567",
  });
});
```

### Conditional Validation

```typescript
const orderForm = form(this.orderModel, (schemaPath) => {
  required(schemaPath.promoCode, {
    message: "Promo code required for discounts",
    when: ({ valueOf }) => valueOf(schemaPath.applyDiscount),
  });
});
```

### Custom Validators

```typescript
import { validate } from "@angular/forms/signals";

const signupForm = form(this.signupModel, (schemaPath) => {
  validate(schemaPath.username, ({ value }) => {
    if (value().includes(" ")) {
      return { kind: "noSpaces", message: "Username cannot contain spaces" };
    }
    return null;
  });
});
```

### Cross-Field Validation

```typescript
const passwordForm = form(this.passwordModel, (schemaPath) => {
  required(schemaPath.password);
  required(schemaPath.confirmPassword);

  validate(schemaPath.confirmPassword, ({ value, valueOf }) => {
    if (value() !== valueOf(schemaPath.password)) {
      return { kind: "mismatch", message: "Passwords do not match" };
    }
    return null;
  });
});
```

### Async Validation

```typescript
import { validateHttp } from "@angular/forms/signals";

const signupForm = form(this.signupModel, (schemaPath) => {
  validateHttp(schemaPath.username, {
    request: ({ value }) => `/api/check-username?u=${value()}`,
    onSuccess: (response: { taken: boolean }) => {
      if (response.taken) {
        return { kind: "taken", message: "Username already taken" };
      }
      return null;
    },
    onError: () => ({
      kind: "networkError",
      message: "Could not verify username",
    }),
  });
});
```

## Conditional Fields

### Hidden Fields

```typescript
import { hidden } from "@angular/forms/signals";

const profileForm = form(this.profileModel, (schemaPath) => {
  hidden(schemaPath.publicUrl, ({ valueOf }) => !valueOf(schemaPath.isPublic));
});
```

```html
@if (!profileForm.publicUrl().hidden()) {
<input [formField]="profileForm.publicUrl" />
}
```

### Disabled Fields

```typescript
import { disabled } from "@angular/forms/signals";

const orderForm = form(this.orderModel, (schemaPath) => {
  disabled(
    schemaPath.couponCode,
    ({ valueOf }) => valueOf(schemaPath.total) < 50,
  );
});
```

### Readonly Fields

```typescript
import { readonly } from "@angular/forms/signals";

const accountForm = form(this.accountModel, (schemaPath) => {
  readonly(schemaPath.username);
});
```

## Form Submission

Use `submit()` to mark all touched and run callback only when valid.

```typescript
import { submit } from "@angular/forms/signals";

@Component({
  template: `
    <form (submit)="onSubmit($event)">
      <input [formField]="form.email" />
      <input [formField]="form.password" />
      <button type="submit" [disabled]="form().invalid()">Submit</button>
    </form>
  `,
})
export class LoginSubmit {
  model = signal({ email: "", password: "" });
  form = form(this.model, (schemaPath) => {
    required(schemaPath.email);
    required(schemaPath.password);
  });

  onSubmit(event: Event) {
    event.preventDefault();
    submit(this.form, async () => {
      await this.authService.login(this.model());
    });
  }
}
```

## Arrays and Dynamic Fields

```typescript
import { applyEach, form, min, required } from "@angular/forms/signals";

interface Order {
  items: Array<{ product: string; quantity: number }>;
}

@Component({
  template: `
    @for (item of orderForm.items; track $index; let i = $index) {
      <div>
        <input [formField]="item.product" placeholder="Product" />
        <input [formField]="item.quantity" type="number" />
        <button type="button" (click)="removeItem(i)">Remove</button>
      </div>
    }
    <button type="button" (click)="addItem()">Add Item</button>
  `,
})
export class OrderFormComponent {
  orderModel = signal<Order>({
    items: [{ product: "", quantity: 1 }],
  });

  orderForm = form(this.orderModel, (schemaPath) => {
    applyEach(schemaPath.items, (item) => {
      required(item.product, { message: "Product required" });
      min(item.quantity, 1, { message: "Min quantity is 1" });
    });
  });

  addItem() {
    this.orderModel.update((m) => ({
      ...m,
      items: [...m.items, { product: "", quantity: 1 }],
    }));
  }

  removeItem(index: number) {
    this.orderModel.update((m) => ({
      ...m,
      items: m.items.filter((_, i) => i !== index),
    }));
  }
}
```

## Displaying Errors

```html
<input [formField]="form.email" />

@if (form.email().touched() && form.email().invalid()) {
<ul class="errors">
  @for (error of form.email().errors(); track error) {
  <li>{{ error.message }}</li>
  }
</ul>
} @if (form.email().pending()) {
<span>Validating...</span>
}
```

## Styling Based on State

```html
<input
  [formField]="form.email"
  [class.is-invalid]="form.email().touched() && form.email().invalid()"
  [class.is-valid]="form.email().touched() && form.email().valid()"
/>
```

## Reset Form

```typescript
async onSubmit() {
  if (!this.form().valid()) return;

  await this.api.submit(this.model());

  // Reset interaction state
  this.form().reset();

  // Reset values
  this.model.set({ email: '', password: '' });
}
```

For advanced Signal Forms patterns, see [references/form-patterns.md](references/form-patterns.md).


## Strict Rules & Common Pitfalls

| Scenario | WRONG | RIGHT |
| --- | --- | --- |
| Accessing flags | `form.field.valid()` | `form.field().valid()` |
| Accessing value | `form.field.value()` | `form.field().value()` |
| Setting value | `form.field.set(x)` | Update model: `this.model.update(...)` |
| Form root flags | `form.invalid()` | `form().invalid()` |
| Double-calling | `form.field()()` | `form.field().value()` |
| Rules context | `({ touched }) => touched()` | `({ state }) => state.touched()` |
| Calling paths | `applyWhen(p.foo, () => p.foo() === 'x')` | `applyWhen(p.foo, ({ valueOf }) => valueOf(p.foo) === 'x')` |
| `applyWhen` args | `applyWhen(condition, () => {...})` | `applyWhen(path, condition, schemaFn)` — 3 args |
| `applyEach` args | `applyEach(s.items, (item, index) => ...)` | `applyEach(s.items, (item) => ...)` — 1 arg |
| Array length | `form.items().length` | `form.items.length` (structural, no `()`) |
| `readonly` attr | `<input readonly [formField]>` | `readonly()` rule in schema |
| `min`/`max` attrs | `<input min="1" max="10" [formField]>` | `min()`/`max()` rules in schema |
| `value` binding | `<input [value]="val" [formField]>` | Don't combine `[value]` with `[formField]` |
| `when` option | `pattern(p.x, /.../, { when: ... })` | `when` works only with `required()` — use `applyWhen` for others |
| Submit callback | `submit(form, () => {...})` | `submit(form, async () => {...})` — MUST be async |
| Async params | `params: s.field` | `params: ({ value }) => value()` |
| Async onError | omitted | `onError` REQUIRED in `validateAsync` |
| `resource()` input | `request: signal` | `params: signal` |
| Nested `@for` | `$parent.$index` | `let outerIndex = $index` |
| `FormState` import | `import { FormState }` | doesn't exist — use `FieldState` |
| Null in model | `signal({ name: null })` | `signal({ name: '' })`, `signal({ age: 0 })`, `signal({ items: [] })` |
| Checkbox + array | `<input type="checkbox" [formField]="form.tags">` (string[]) | checkboxes bind ONLY to `boolean`; use `<select multiple>` for arrays |

### Async Validation — `validateAsync()`

`validate()` is sync-only. For async checks (uniqueness, server lookups), use `validateAsync()` backed by a `resource()`:

```typescript
import { resource } from '@angular/core';
import { validateAsync } from '@angular/forms/signals';

userForm = form(this.userModel, (s) => {
  validateAsync(s.username, {
    params: ({ value }) => value(),               // MUST be a function
    factory: (username) => resource({
      params: username,                            // 'params', not 'request'
      loader: async ({ params: value }) => checkUsernameTaken(value),
    }),
    onSuccess: (isTaken) =>
      isTaken ? { kind: 'taken', message: 'Username already taken' } : undefined,
    onError: () => ({ kind: 'error', message: 'Validation failed' }),  // REQUIRED
  });
});
```

### `debounce()` — Delay Model Sync

Delays writing UI input to the model — pairs naturally with `validateAsync`/search-as-you-type to cut request volume:

```typescript
import { debounce } from '@angular/forms/signals';

userForm = form(this.userModel, (s) => {
  debounce(s.username, 300);
});
```

### `applyWhen` — Conditional Sub-Schemas

Takes 3 args: `(path, condition, schemaFn)`. Inside the schema, paths are NOT signals/callable — read via `valueOf`/`stateOf`:

```typescript
applyWhen(
  s.spouse,
  ({ valueOf }) => valueOf(s.status) === 'joint',
  (spousePath) => {
    required(spousePath.name);
  },
);
```

### Nested `@for` — No `$parent`

```html
@for (item of form.items; track $index; let outerIndex = $index) {
  @for (option of item.options; track $index) {
    <button (click)="removeOption(outerIndex, $index)">Remove</button>
  }
}
```

## Multi-Step Wizard

Use one root model + one root form. Show fields by current step.

```typescript
import { Component, computed, signal } from '@angular/core';
import { form, required, minLength } from '@angular/forms/signals';

type Step = 0 | 1 | 2;

interface SignupModel {
  account: { email: string; password: string };
  profile: { firstName: string; lastName: string };
  consent: { accepted: boolean };
}

@Component({
  selector: 'app-signup-wizard',
  template: `
    @if (step() === 0) {
      <input [formField]="signupForm.account.email" placeholder="Email" />
      <input [formField]="signupForm.account.password" type="password" placeholder="Password" />
    }

    @if (step() === 1) {
      <input [formField]="signupForm.profile.firstName" placeholder="First name" />
      <input [formField]="signupForm.profile.lastName" placeholder="Last name" />
    }

    @if (step() === 2) {
      <label>
        <input type="checkbox" [formField]="signupForm.consent.accepted" />
        Accept terms
      </label>
    }

    <button type="button" (click)="prev()" [disabled]="step() === 0">Back</button>
    <button type="button" (click)="next()" [disabled]="!canGoNext()">Next</button>
  `,
})
export class SignupWizard {
  step = signal<Step>(0);

  signupModel = signal<SignupModel>({
    account: { email: '', password: '' },
    profile: { firstName: '', lastName: '' },
    consent: { accepted: false },
  });

  signupForm = form(this.signupModel, (p) => {
    required(p.account.email, { message: 'Email required' });
    minLength(p.account.password, 8, { message: 'Min 8 chars' });
    required(p.profile.firstName);
    required(p.profile.lastName);
  });

  canGoNext = computed(() => {
    const s = this.step();
    if (s === 0) return this.signupForm.account.email().valid() && this.signupForm.account.password().valid();
    if (s === 1) return this.signupForm.profile.firstName().valid() && this.signupForm.profile.lastName().valid();
    return this.signupForm.consent.accepted().value() === true;
  });

  next() {
    if (!this.canGoNext()) return;
    this.step.update(s => (s < 2 ? ((s + 1) as Step) : s));
  }

  prev() {
    this.step.update(s => (s > 0 ? ((s - 1) as Step) : s));
  }
}
```

## Schema-Driven Dynamic Fields

Drive UI from metadata. Bind each entry to form tree path.

```typescript
import { Component, signal } from '@angular/core';
import { form, required, minLength } from '@angular/forms/signals';

interface DynamicModel {
  companyName: string;
  vatId: string;
  contactEmail: string;
}

type DynamicField =
  | { key: 'companyName'; label: string; type: 'text'; required: true; minLen?: number }
  | { key: 'vatId'; label: string; type: 'text'; required: true; minLen?: number }
  | { key: 'contactEmail'; label: string; type: 'email'; required: true; minLen?: number };

@Component({
  template: `
    @for (field of fields(); track field.key) {
      <label>
        {{ field.label }}
        <input [type]="field.type" [formField]="form[field.key]" />
      </label>
    }
  `,
})
export class DynamicCompanyForm {
  fields = signal<DynamicField[]>([
    { key: 'companyName', label: 'Company', type: 'text', required: true, minLen: 2 },
    { key: 'vatId', label: 'VAT ID', type: 'text', required: true, minLen: 8 },
    { key: 'contactEmail', label: 'Contact email', type: 'email', required: true },
  ]);

  model = signal<DynamicModel>({
    companyName: '',
    vatId: '',
    contactEmail: '',
  });

  form = form(this.model, (p) => {
    required(p.companyName);
    required(p.vatId);
    required(p.contactEmail);
    minLength(p.companyName, 2);
    minLength(p.vatId, 8);
  });
}
```

## Async Validation with Debounce and Stale Response Guard

Use value snapshot + request key. Ignore stale responses.

```typescript
import { form, validateHttp } from '@angular/forms/signals';

form(this.model, (p) => {
  validateHttp(p.username, {
    request: ({ value }) => {
      const username = value().trim();
      return `/api/users/check-username?username=${encodeURIComponent(username)}`;
    },
    onSuccess: (response: { taken: boolean; username: string }, ctx) => {
      // Guard against stale async responses.
      if (response.username !== ctx.value()) return null;
      return response.taken
        ? { kind: 'usernameTaken', message: 'Username already taken' }
        : null;
    },
    onError: () => ({ kind: 'network', message: 'Validation service unavailable' }),
  });
});
```

## Form Performance Patterns

- Keep model shape flat when possible. Deep nesting = more dependency churn.
- Split large forms by feature component. Pass field subtrees (`form.address`, `form.billing`) as inputs.
- Use `ChangeDetectionStrategy.OnPush` in form-heavy components.
- Render only needed fields with native control flow (`@if`, `@for`).
- Run expensive computed logic outside template hot path.

```typescript
import { ChangeDetectionStrategy, Component, input } from '@angular/core';

@Component({
  selector: 'app-address-fields',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <input [formField]="addressForm().street" placeholder="Street" />
    <input [formField]="addressForm().zip" placeholder="ZIP" />
  `,
})
export class AddressFields {
  addressForm = input.required<any>();
}
```

## Testing Strategy

Test by state transitions, not just DOM snapshots.

```typescript
it('marks email invalid when empty', () => {
  const cmp = createComponent();

  cmp.form.email().value.set('');
  cmp.form.email().markAsTouched();

  expect(cmp.form.email().invalid()).toBe(true);
  expect(cmp.form.email().errors()[0].kind).toBe('required');
});

it('submits only when form valid', async () => {
  const cmp = createComponent();
  const submitSpy = vi.spyOn(cmp.api, 'submit').mockResolvedValue(undefined);

  cmp.model.set({ email: 'a@b.com', password: '12345678' });
  await cmp.onSubmit();

  expect(submitSpy).toHaveBeenCalledTimes(1);
});
```
