# ADR-[NNN]: [Short Title of Architectural Decision]

- **Status:** [Proposed | Accepted | Superseded | Deprecated]
- **Date:** [YYYY-MM-DD]
- **Deciders:** [User / Architect / Team]
- **Target:** [App name or Feature name]
- **Scope:** [Greenfield System Architecture | Feature Architecture | Major Refactor]

## Context and Problem Statement

[What is the context and problem to solve? 2-4 sentences explaining why this architectural decision is needed.]

### Multi-Axis Context Analysis

- **Scope & Boundaries:** [Core user journey, primary actors, and explicit boundaries]
- **Scale & Performance:** [Expected load, throughput, concurrency, and latency constraints]
- **Data & Consistency:** [State ownership, persistence requirements, consistency guarantees]
- **Integration & Blast Radius:** [Touched components, external APIs, contract changes]
- **Security & Resilience:** [Auth/authz, tenant isolation, error recovery, fallback behavior]
- **Operations & DX:** [Team familiarity, hosting/infra constraints, local development ergonomics]

## Decision Drivers

- [Driver 1: e.g. High concurrency / real-time latency requirements]
- [Driver 2: e.g. Maintainability and clean separation of concerns]
- [Driver 3: e.g. Existing stack conventions or team familiarity]
- [Driver 4: e.g. Operational simplicity and delivery velocity]

## Considered Options

### Option 1: [Name of Option 1]

- **Description:** [Brief architectural approach, component boundaries, patterns used]
- **Good, because:** [Key benefit 1]
- **Good, because:** [Key benefit 2]
- **Bad, because:** [Key drawback / limitation]
- **Risks:** [Associated failure mode or operational risk]

### Option 2: [Name of Option 2]

- **Description:** [Brief architectural approach]
- **Good, because:** [Key benefit 1]
- **Good, because:** [Key benefit 2]
- **Bad, because:** [Key drawback / limitation]
- **Risks:** [Associated failure mode or operational risk]

### Option 3: [Name of Option 3] (Optional)

- **Description:** [Brief architectural approach]
- **Good, because:** [Key benefit 1]
- **Bad, because:** [Key drawback]
- **Risks:** [Associated failure mode or operational risk]

## Decision Outcome

Chosen option: **[Option N: Name]**, because [justification directly linking choice to decision drivers].

### Positive Consequences

- [Positive impact on architecture, developer experience, scalability]
- [Alignment with DevFlow ethos and project conventions]

### Negative Consequences / Trade-offs

- [Accepted downside or complexity that team must manage]
- [Operational, dependency, or tooling overhead]

## Architectural Blueprint

```text
[ASCII diagram or component layout showing boundaries, interactions, and data flow]
```

- **Key Components:**
  - `[Component/Layer 1]`: [Responsibility]
  - `[Component/Layer 2]`: [Responsibility]
- **Data Contracts & APIs:** [Protocols, payload formats, database tables/entities]
- **Security & Cross-cutting Concerns:** [Auth, error boundaries, rate limits, caching]

## Next Steps in DevFlow

- [ ] For greenfield app: Run `/devflow.setup` using the chosen stack configuration
- [ ] For feature: Run `/devflow.task` referencing `docs/adr/ADR-[NNN]-[slug].md`
