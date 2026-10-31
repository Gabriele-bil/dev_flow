# Implement notify-user template

Used by `devflow.implement` Step 8 — respond with this format after implementation completes.

```text
✅ Implementation complete: [type]/[NNN]_[feature-name]

### Files created
- `path/to/file.ext`
- ...

### Files modified
- `path/to/file.ext`
- ...

### Deviations from plan
- [file or section]: [reason for deviation]  ← also written to plan.md
  (none if fully aligned)

### Commands run
- codegen (per adapter): [yes | no]
- format (per adapter): ✅ / ❌ (resolved after [N] attempts)
- analyze/typecheck (per adapter): ✅ / ❌ (resolved after [N] attempts)

Next: /devflow:beautify (`quick` profile: /devflow:test — beautify is skipped)
```
