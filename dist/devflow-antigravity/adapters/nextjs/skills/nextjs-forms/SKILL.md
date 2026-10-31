---
name: nextjs-forms
description: React Hook Form + Zod 4 + shadcn/ui Field + Server Actions. Load when touching useForm, zodResolver, or z.object patterns.
---

# Next.js Forms

## Purpose

One Zod schema shared by form and Server Action; React Hook Form `Controller` + shadcn/ui `Field` for UI. Full form example: `references/forms-patterns.md`.

## When NOT to Use

- File matches no row of `steps/implement.md` → skill load decision matrix
- Server Action body (persist, invalidate cache) → `nextjs-server`
- Visual styling of inputs/buttons → `nextjs-ui`

## Baseline

| Package | Role |
| --- | --- |
| `react-hook-form` | Form state, `Controller`, `useFieldArray` |
| `@hookform/resolvers` (`/zod`) | RHF ↔ Zod bridge |
| `zod` 4 | Schema + type inference |
| shadcn/ui `Field`, `FieldLabel`, `FieldDescription`, `FieldError`, `FieldGroup` | Accessible field layout |

shadcn `Form`/`FormField`/`FormItem` wrappers → legacy, do not use; use `Controller` + `Field` instead.

## Rules

- Schema in route `_lib/schema.ts`, defined before form, reused unchanged in Server Action. Never duplicated.
- Zod 4 API: top-level formats (`z.email()`, `z.url()`, `z.uuid()`); errors via `error.issues` and `z.flattenError(error)`. Check current Zod docs with Context7 before using a method not shown here.
- `defaultValues` explicit for every field.
- Each field: `<Field data-invalid={fieldState.invalid}>`, control gets `id={field.name}` + `aria-invalid`, `FieldLabel htmlFor` matches, `FieldError` when invalid.
- Submit: `form.handleSubmit` → `startTransition(async () => await action(data))`; map server field errors back with `form.setError`.
- Progressive-enhancement form without RHF: `useActionState(action, initialState)` with `<form action={formAction}>`; still validate server-side.
- Submit button disabled while `isPending` / `formState.isSubmitting`.
- Multi-step: one `useForm`; validate step with `await form.trigger([...fields])` before advancing.

## Anti-patterns

- Client-only validation — Server Action must `safeParse` again.
- Manual loading flags instead of `isPending` / `useFormStatus`.
- Field without label or without `aria-invalid` on error.

## Review checklist

- [ ] One schema, reused in Server Action
- [ ] `zodResolver(schema)` + explicit `defaultValues`
- [ ] Every field: `Field` + `FieldLabel` + `FieldError`, `aria-invalid` wired
- [ ] Server errors mapped with `form.setError`
- [ ] Submit disabled while pending

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` via `steps/implement.md` → skill load decision matrix (`useForm`, `zodResolver`, `z.object`, `_lib/schema.ts`) |
| Reads | `references/forms-patterns.md` |
| Writes | Form components, Zod schemas |
| Related | `nextjs-server` (Server Actions), `nextjs-ui` (shadcn/ui components), `nextjs-testing` |
