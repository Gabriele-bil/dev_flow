# Next.js Client Components — project patterns

Loaded on demand from `../SKILL.md`. React APIs change rarely but check current docs with Context7 before using a hook not listed here.

## Boundary at the leaf

```tsx
// app/(app)/dashboard/page.tsx — Server Component
export default async function Page() {
  const data = await getDashboard()
  return (
    <>
      <StaticSummary data={data} />
      <InteractiveCounter initialCount={data.count} /> {/* only this file has 'use client' */}
    </>
  )
}
```

## Serialize before crossing the boundary

```tsx
// server
<PostCard createdAt={post.createdAt.toISOString()} />

// client
export function PostCard({ createdAt }: { createdAt: string }) {
  return <time dateTime={createdAt}>{new Date(createdAt).toLocaleDateString()}</time>
}
```

## `ref` as prop (React 19)

```tsx
export function LabeledInput({ ref, label, ...props }: { ref?: React.Ref<HTMLInputElement>; label: string } & React.ComponentProps<'input'>) {
  const id = useId()
  return (
    <>
      <label htmlFor={id}>{label}</label>
      <input id={id} ref={ref} {...props} />
    </>
  )
}
```

## Suspense around `useSearchParams`

```tsx
// page.tsx (server)
<Suspense fallback={<SearchBarSkeleton />}>
  <SearchBar /> {/* 'use client', calls useSearchParams() */}
</Suspense>
```
