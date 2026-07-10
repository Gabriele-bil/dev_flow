---
name: nextjs-forms
description: React Hook Form + Zod + shadcn/ui Form + Server Actions. Load when touching useForm, zodResolver, or z.object patterns.
---

# Next.js Forms

react-hook-form + @hookform/resolvers/zod + zod + shadcn/ui Form components. Zod schema = source of truth for client and server.

Full code: `references/forms-patterns.md`.

## Baseline

| Package | Role |
| --- | --- |
| `react-hook-form` | Form state, validation orchestration |
| `@hookform/resolvers/zod` | Bridge RHF ↔ Zod |
| `zod` | Schema definition and type inference |
| `shadcn/ui` Form components | Accessible form UI primitives |

Zod schema defined once, before the form, reused unchanged in Server Action validation — never duplicated.

## Multi-step forms

- Single `useForm` for all steps OR partial schema with `trigger()` for step-by-step validation
- Step state: `useState` locally or Zustand if state persists across mounts
- Validate current step before advancing: `await form.trigger(['field1', 'field2'])`

## Anti-patterns

- Validating client-side only without Server Action validation
- Duplicating Zod schema — one schema, reused everywhere
- Managing loading state manually instead of `useTransition` or `useFormStatus`
- Not mapping server errors with `form.setError` after failed action response
- `<form action={serverAction}>` without client validation — use hybrid pattern

## Review checklist

- [ ] Zod schema defined once, reused in Server Action
- [ ] `zodResolver` configured
- [ ] `defaultValues` explicit — prevents uncontrolled → controlled warning
- [ ] Server errors mapped with `form.setError`
- [ ] Submit button disabled during `isPending`/`isSubmitting`
- [ ] `FormMessage` present for every validated field

## I/O Reference

| | |
| --- | --- |
| Invoked by | `devflow-implement` for files with `useForm`, `zodResolver`, `z.object` |
| Related | `nextjs-server` (Server Actions), `nextjs-ui` (shadcn/ui components), `nextjs-testing` |
