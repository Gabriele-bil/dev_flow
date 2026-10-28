# Angular adapter — Plan step

Loaded by `devflow-plan` together with the adapter core (`ADAPTER.md`).

## Plan: extra sections and templates

Include these in `plan.md` when applicable (after core sections from `devflow-plan`).

### Dependency ordering (layering)

Order the **File list** bottom-up by layer ownership. Source of truth for Angular boundaries and dependency flow:

- `@devflow/adapters/angular/skills/angular-architecture/SKILL.md`

### State plan (add when state changes)

Use the structure and constraints from:

- `@devflow/adapters/angular/skills/angular-state/SKILL.md`

### Forms plan (add when forms change)

Use the structure and constraints from:

- `@devflow/adapters/angular/skills/angular-forms/SKILL.md`

### Data model (omit if no new persistent entities)

When `devflow-plan` Step 4c generates `data-model.md`: use it as the single source of truth for entity definitions before writing any interface, DTO, or model files. Fields in `data-model.md` map to TypeScript interfaces — do not invent property names or types that diverge from the data model.
