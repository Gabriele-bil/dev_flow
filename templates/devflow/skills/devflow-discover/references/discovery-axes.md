# Architectural Discovery Axes

Six-lens framework for analyzing problems and extracting context before proposing architectural solutions. Used by `devflow.discover` Step 2.

## 1. Functional Scope & Boundaries

- **Core focus:** Exact problem boundary, actors, critical user journeys, edge cases, out-of-scope items.
- **Probe questions:**
  - What is the primary user interaction and expected outcome?
  - What edge cases (failures, cancellations, concurrent edits) are in scope?
  - What should explicitly NOT be solved by this architecture?
- **Red flags:** Feature creep, mixed responsibilities, undefined actor roles.

## 2. Scale, Volume & Performance

- **Core focus:** Concurrency, read/write ratios, throughput, payload sizes, latency budgets.
- **Probe questions:**
  - What is the expected peak load (req/sec, active users, data volume)?
  - Is latency mission-critical (<100ms) or is standard API response time acceptable?
  - Is real-time push (WebSockets/SSE) required, or does polling/on-demand fetch suffice?
- **Red flags:** Premature distributed complexity for low-traffic loads, or ignoring burst traffic.

## 3. Data Architecture & Consistency

- **Core focus:** Entity models, relational vs document storage, consistency guarantees, state ownership.
- **Probe questions:**
  - Does this data require ACID transactions or is eventual consistency acceptable?
  - Who owns this state (client, server session, durable database)?
  - How will schema migrations or backwards compatibility be handled?
- **Red flags:** Distributed transactions without sagas, unindexed relation cascades, duplicate source of truth.

## 4. Integration Surface & Blast Radius

- **Core focus:** Existing codebase boundaries, external APIs, shared contracts, downstream consumers.
- **Probe questions:**
  - Which existing services, modules, or database tables must be modified?
  - Are external third-party APIs involved (webhooks, rate limits, sandbox environments)?
  - Will existing client consumers break if API payload shapes change?
- **Red flags:** Tight coupling across domain boundaries, breaking shared database schemas.

## 5. Security, Compliance & Resilience

- **Core focus:** Authentication, authorization, sensitive data (PII/secrets), fault tolerance, retries.
- **Probe questions:**
  - What permissions or tenant isolation rules apply to this operation?
  - What happens when a dependent service or network call fails (retry, fallback, circuit breaker)?
  - Are sensitive tokens, PII, or audit trails involved?
- **Red flags:** Missing tenant scoping, unprotected endpoints, infinite retry storms without backoff.

## 6. Operational Ergonomics & DX

- **Core focus:** Team familiarity, operational complexity, hosting constraints, maintainability, debugging.
- **Probe questions:**
  - Does the team already maintain this technology/infra, or does it introduce a new operational burden?
  - Can developers run and test this architecture locally without complex remote cloud dependencies?
  - How will this architecture be monitored and debugged in production?
- **Red flags:** New cloud services or languages for minor features, unverifiable local environments.
