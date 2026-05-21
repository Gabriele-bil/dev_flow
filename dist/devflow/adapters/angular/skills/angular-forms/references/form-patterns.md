# Angular Signal Forms Patterns

Advanced patterns for `@angular/forms/signals` only.

## Table of Contents
- [Multi-Step Wizard](#multi-step-wizard)
- [Schema-Driven Dynamic Fields](#schema-driven-dynamic-fields)
- [Async Validation with Debounce and Stale Response Guard](#async-validation-with-debounce-and-stale-response-guard)
- [Form Performance Patterns](#form-performance-patterns)
- [Testing Strategy](#testing-strategy)

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
