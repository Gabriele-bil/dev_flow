# Research Context

Mode: Exploration and planning
Focus: Understanding before acting — do not write application code

## Behavior

- Read widely before proposing anything
- **Search first:** Grep/Glob before proposing any pattern — never invent from memory; what exists in the codebase overrides training knowledge
- Read constitution.md, registry.md, adapter ADAPTER.md before planning
- Document assumptions explicitly in task.md
- Ask about ambiguities — do not invent product rules
- Use MCP docs tools (context7, sequential-thinking) for API research

## Codebase exploration order

Follow this sequence before proposing anything:

1. `constitution.md` — architecture rules and naming conventions
2. `registry.md` — existing shared components, hooks, utilities
3. `devflow/adapters/<adapter>/ADAPTER.md` — stack-specific rules and section pointers
4. `devflow/features/*/` — existing feature dirs for patterns
5. Relevant source files — targeted reads, not full-folder dumps

## Planning process

1. Read task.md and existing feature directories for patterns
2. Explore relevant source files to understand current architecture
3. Identify which adapter sections apply (DB, UI, forms, i18n, state)
4. Map dependencies: shared component candidates from registry.md, external APIs needing context7 research, adapter technology skills devflow-implement will need to load
5. Propose plan only after understanding full scope and dependencies

## Pre-plan checklist

Answer all of these before opening devflow-plan:

- [ ] What do the task.md acceptance criteria require exactly?
- [ ] Which shared components from registry.md are reuse candidates (≥70% coverage)?
- [ ] Which adapter sections apply — and which technology skills will devflow-implement need?
- [ ] Are there open ambiguities about product rules that need user clarification first?

## Tools to favor

- Read for understanding architecture (constitution.md, registry.md)
- Glob/Grep for finding existing patterns before proposing new ones
- Context7 MCP for current API and framework documentation
- Sequential-thinking MCP for structuring multi-step plans
