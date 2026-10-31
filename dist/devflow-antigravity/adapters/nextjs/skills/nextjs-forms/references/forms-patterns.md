# Next.js Forms — project patterns

Loaded on demand from `../SKILL.md`. shadcn/ui and Zod evolve quickly: check current docs with Context7 before adding a field type not shown here.

## Shared schema

```ts
// app/(app)/settings/_lib/schema.ts
import { z } from 'zod'

export const profileSchema = z.object({
  name: z.string().min(1, 'Name required').max(50),
  email: z.email('Invalid email'),
  bio: z.string().max(200).optional(),
})

export type ProfileInput = z.infer<typeof profileSchema>
```

## Form — RHF `Controller` + shadcn `Field` + Server Action

```tsx
'use client'
import { useTransition } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { profileSchema, type ProfileInput } from './_lib/schema'
import { updateProfile } from '../actions'

export function ProfileForm({ initial }: { initial: ProfileInput }) {
  const [isPending, startTransition] = useTransition()
  const form = useForm<ProfileInput>({ resolver: zodResolver(profileSchema), defaultValues: initial })

  function onSubmit(data: ProfileInput) {
    startTransition(async () => {
      const result = await updateProfile(data)
      if (!result.success && typeof result.error === 'object') {
        for (const [name, messages] of Object.entries(result.error)) {
          form.setError(name as keyof ProfileInput, { message: messages?.[0] })
        }
      }
    })
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <FieldGroup>
        <Controller
          name="email"
          control={form.control}
          render={({ field, fieldState }) => (
            <Field data-invalid={fieldState.invalid}>
              <FieldLabel htmlFor={field.name}>Email</FieldLabel>
              <Input {...field} id={field.name} type="email" aria-invalid={fieldState.invalid} />
              {fieldState.invalid && <FieldError errors={[fieldState.error]} />}
            </Field>
          )}
        />
        <Button type="submit" disabled={isPending}>Save</Button>
      </FieldGroup>
    </form>
  )
}
```

Server side: `updateProfile(data: unknown)` runs `profileSchema.safeParse(data)` and returns `{ success: false, error: z.flattenError(parsed.error).fieldErrors }` on failure (pattern in `nextjs-server` reference).

## Without RHF — `useActionState`

```tsx
const [state, formAction, isPending] = useActionState(createItem, null) // CreateItemState includes null
return <form action={formAction}>…</form>
```

## Field types

| Field | Pattern |
| --- | --- |
| Select, Checkbox, Switch, RadioGroup | shadcn control inside `Controller` + `Field` (`orientation="horizontal"` for checkbox/switch) |
| Array of rows | `useFieldArray` |
| Date | `<Input type="date">` or shadcn date picker in `Controller` |
