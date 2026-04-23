---
name: angular-forms
description: Build signal-based forms in Angular v21+ using the new Signal Forms API. Use for form creation with automatic two-way binding, schema-based validation, field state management, and dynamic forms. Triggers on form implementation, adding validation, creating multi-step forms, or building forms with conditional fields. Signal Forms are experimental but recommended for new Angular projects. Don't use for template-driven forms without signals or third-party form libraries like Formly or ngx-formly.
---

# Angular Signal Forms

Build type-safe, reactive forms with Signal Forms API. One model signal = source of truth.

Note: Signal Forms experimental in Angular v21.

## Basic Setup

```typescript
import { Component, signal } from '@angular/core';
import { form, FormField, required, email } from '@angular/forms/signals';

interface LoginData {
  email: string;
  password: string;
}

@Component({
  selector: 'app-login',
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
    email: '',
    password: '',
  });

  // Form schema + validators
  loginForm = form(this.loginModel, (schemaPath) => {
    required(schemaPath.email, { message: 'Email is required' });
    email(schemaPath.email, { message: 'Enter a valid email address' });
    required(schemaPath.password, { message: 'Password is required' });
  });

  onSubmit(event: Event) {
    event.preventDefault();
    if (this.loginForm().valid()) {
      const credentials = this.loginModel();
      console.log('Submitting:', credentials);
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
    theme: 'light' | 'dark';
  };
}

const userModel = signal<UserProfile>({
  name: '',
  email: '',
  age: null,
  preferences: {
    newsletter: false,
    theme: 'light',
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
  name: 'Alice',
  email: 'alice@example.com',
  age: 30,
  preferences: { newsletter: true, theme: 'dark' },
});

this.userForm.name().value.set('Bob');
this.userForm.age().value.update(age => (age ?? 0) + 1);
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
} from '@angular/forms/signals';

const userForm = form(this.userModel, (schemaPath) => {
  required(schemaPath.name, { message: 'Name is required' });
  email(schemaPath.email, { message: 'Invalid email' });
  min(schemaPath.age, 18, { message: 'Must be 18+' });
  max(schemaPath.age, 120, { message: 'Invalid age' });
  minLength(schemaPath.password, 8, { message: 'Min 8 characters' });
  maxLength(schemaPath.bio, 500, { message: 'Max 500 characters' });
  pattern(schemaPath.phone, /^\d{3}-\d{3}-\d{4}$/, {
    message: 'Format: 555-123-4567',
  });
});
```

### Conditional Validation

```typescript
const orderForm = form(this.orderModel, (schemaPath) => {
  required(schemaPath.promoCode, {
    message: 'Promo code required for discounts',
    when: ({ valueOf }) => valueOf(schemaPath.applyDiscount),
  });
});
```

### Custom Validators

```typescript
import { validate } from '@angular/forms/signals';

const signupForm = form(this.signupModel, (schemaPath) => {
  validate(schemaPath.username, ({ value }) => {
    if (value().includes(' ')) {
      return { kind: 'noSpaces', message: 'Username cannot contain spaces' };
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
      return { kind: 'mismatch', message: 'Passwords do not match' };
    }
    return null;
  });
});
```

### Async Validation

```typescript
import { validateHttp } from '@angular/forms/signals';

const signupForm = form(this.signupModel, (schemaPath) => {
  validateHttp(schemaPath.username, {
    request: ({ value }) => `/api/check-username?u=${value()}`,
    onSuccess: (response: { taken: boolean }) => {
      if (response.taken) {
        return { kind: 'taken', message: 'Username already taken' };
      }
      return null;
    },
    onError: () => ({
      kind: 'networkError',
      message: 'Could not verify username',
    }),
  });
});
```

## Conditional Fields

### Hidden Fields

```typescript
import { hidden } from '@angular/forms/signals';

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
import { disabled } from '@angular/forms/signals';

const orderForm = form(this.orderModel, (schemaPath) => {
  disabled(schemaPath.couponCode, ({ valueOf }) => valueOf(schemaPath.total) < 50);
});
```

### Readonly Fields

```typescript
import { readonly } from '@angular/forms/signals';

const accountForm = form(this.accountModel, (schemaPath) => {
  readonly(schemaPath.username);
});
```

## Form Submission

Use `submit()` to mark all touched and run callback only when valid.

```typescript
import { submit } from '@angular/forms/signals';

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
  model = signal({ email: '', password: '' });
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
import { applyEach, form, min, required } from '@angular/forms/signals';

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
    items: [{ product: '', quantity: 1 }],
  });

  orderForm = form(this.orderModel, (schemaPath) => {
    applyEach(schemaPath.items, (item) => {
      required(item.product, { message: 'Product required' });
      min(item.quantity, 1, { message: 'Min quantity is 1' });
    });
  });

  addItem() {
    this.orderModel.update(m => ({
      ...m,
      items: [...m.items, { product: '', quantity: 1 }],
    }));
  }

  removeItem(index: number) {
    this.orderModel.update(m => ({
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
}

@if (form.email().pending()) {
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

