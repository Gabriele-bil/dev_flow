# Data model template (plan Step 4c)

Written to `devflow/features/[NNN]_[feature-name]/data-model.md` when the File List contains a migration, DTO, domain model, schema file or new entity type.

```markdown
# Data Model - [Feature Name]

**Feature:** PLAN-[NNN]
**Date:** [YYYY-MM-DD]

| Entity | Fields | Relationships | Lifecycle states | Validation rules |
|--------|--------|---------------|------------------|------------------|
| [EntityName] | [field: type, ...] | [belongs to / has many / ...] | [created / active / archived / ...] | [required, max-length N, format, ...] |
```

## Rules

- No class names, annotations, or framework types — technology-agnostic only.
- One row per domain concept; split conflated concepts.
- Adapter skills derive stack-specific types from this file.
