# Next.js Forms — Code Patterns

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

## Common field patterns

| Field type | Pattern |
| --- | --- |
| Select | `<Select>` shadcn + `Controller` from react-hook-form |
| Checkbox | `<Checkbox>` shadcn + `Controller` |
| Date | `<Input type="date">` or shadcn date picker |
| Array of fields | `useFieldArray` from react-hook-form |
