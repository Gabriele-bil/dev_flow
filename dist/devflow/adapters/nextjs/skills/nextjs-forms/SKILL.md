---
name: nextjs-forms
description: React Hook Form with Zod validation, shadcn/ui Form components, and Server Action integration. Load when touching files with useForm, zodResolver, or z.object patterns.
---

# Next.js Forms

react-hook-form + @hookform/resolvers/zod + zod + shadcn/ui Form components. Zod schema = source of truth for client and server.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Baseline

| Package | Role |
| --- | --- |
| `react-hook-form` | Form state, validation orchestration |
| `@hookform/resolvers/zod` | Bridge RHF ↔ Zod |
| `zod` | Schema definition and type inference |
| `shadcn/ui` Form components | Accessible form UI primitives |

## Zod schema — source of truth

Define schema BEFORE the form. Reuse in Server Action validation. Never duplicate.

```ts
// app/(app)/settings/_lib/schema.ts
import { z } from 'zod'

export const profileSchema = z.object({
  name: z.string().min(1, 'Name required').max(50),
  email: z.string().email('Invalid email'),
  bio: z.string().max(200).optional(),
})

export type ProfileFormData = z.infer<typeof profileSchema>
```

## React Hook Form + Zod setup

```tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { profileSchema, type ProfileFormData } from './_lib/schema'

export function ProfileForm() {
  const form = useForm<ProfileFormData>({
    resolver: zodResolver(profileSchema),
    defaultValues: { name: '', email: '', bio: '' },
  })

  const { formState: { isSubmitting, errors } } = form
  // ...
}
```

## shadcn/ui Form components — structure

```tsx
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'

return (
  <Form {...form}>
    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
      <FormField
        control={form.control}
        name="email"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Email</FormLabel>
            <FormControl>
              <Input placeholder="email@example.com" {...field} />
            </FormControl>
            <FormMessage />  {/* validation error rendered automatically */}
          </FormItem>
        )}
      />
      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Saving...' : 'Save'}
      </Button>
    </form>
  </Form>
)
```

## Server Action integration — hybrid pattern

```tsx
'use client'
import { useTransition } from 'react'
import { updateProfile } from './_lib/actions'

export function ProfileForm() {
  const [isPending, startTransition] = useTransition()
  const form = useForm<ProfileFormData>({ resolver: zodResolver(profileSchema) })

  function onSubmit(data: ProfileFormData) {
    startTransition(async () => {
      const result = await updateProfile(data)
      if (!result.success) {
        // Map server errors to form fields
        form.setError('email', { message: result.error })
        return
      }
      // success: redirect, toast, etc.
    })
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        {/* fields */}
        <Button type="submit" disabled={isPending}>Save</Button>
      </form>
    </Form>
  )
}
```

## Server Action — validate with same schema

```ts
// app/(app)/settings/_lib/actions.ts
'use server'
import { profileSchema } from './schema'

export async function updateProfile(data: unknown) {
  const parsed = profileSchema.safeParse(data)
  if (!parsed.success) {
    return { success: false, error: parsed.error.errors[0].message }
  }

  // ... persist
  return { success: true }
}
```

## Multi-step forms

- Single `useForm` for all steps OR partial schema with `trigger()` for step-by-step validation
- Step state: `useState` locally or Zustand if state persists across mounts
- Validate current step before advancing: `await form.trigger(['field1', 'field2'])`

## Common field patterns

| Field type | Pattern |
| --- | --- |
| Select | `<Select>` shadcn + `Controller` from react-hook-form |
| Checkbox | `<Checkbox>` shadcn + `Controller` |
| Date | `<Input type="date">` or shadcn date picker |
| Array of fields | `useFieldArray` from react-hook-form |

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
