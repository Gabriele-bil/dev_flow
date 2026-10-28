# Registry update templates

Used by `devflow.implement` Step 7 — after all files implemented, update `registry.md` for every element written to the shared folder or identified as reusable.

**Mandatory (write immediately, no confirmation needed):**

- Any component, widget, or utility written to the project's shared folder (e.g. `lib/shared/`, `src/shared/`, `components/shared/`) during this session.
- Any helper, hook, or service class placed in a shared/common path per `constitution.md`.

**Proposed (write only after explicit user confirmation):**

- New architectural patterns or conventions that are reusable but not yet in a shared path.

For each mandatory entry, add a row to `registry.md` using the project's existing registry format:

```text
✅ Registry updated: [component/widget/utility name]
Path: [shared path]
[1-2 sentences on what it solves and when to use it.]
```

For proposed entries, surface them first:

```text
🔍 New pattern found: [pattern name]
[1-2 sentences describing what it solves and how it works.]

Add to registry.md? [yes / no]
```

> **Rule:** anything written to a shared folder that is missing from `registry.md` is invisible to future agents. Never leave a shared file unregistered.
