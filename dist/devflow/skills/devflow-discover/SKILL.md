---
name: devflow-discover
description: "Guides architectural discovery for greenfield applications or complex features, compares technical options, and records decisions in ADRs. Use when exploring architecture choices, evaluating trade-offs, or before devflow.setup or devflow.task."
argument-hint: "[--app <name>] [--feature <slug>] [topic-or-scope]"
---

# Skill: devflow.discover

## Purpose

Interactive architectural discovery for greenfield applications or complex features. Analyzes problems across six architectural axes, asks targeted context questions, compares technical options, and records decisions in `docs/adr/ADR-NNN-[title].md`.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Architecture already decided and documented in `constitution.md` or existing ADR — go to `devflow.task` or `devflow.plan`
- Feature is small or standard extension following established codebase patterns without architectural unknowns — go to `devflow.task`
- Fixing a bug or regression in existing code — use `devflow.backprop` or `devflow.hotfix`
- Task is written and needs clarification on user requirements rather than architecture — use `devflow.clarify`

## Input contract

Before proceeding, verify:

- [ ] Free text argument, user prompt, or attached file provides topic or scope to explore
- [ ] Monorepo: if `devflow/config.md` declares `## Apps`, target app resolved (`--app <name>` or asked)
- [ ] Project directory accessible to inspect existing code (for feature mode) or write `docs/adr/`

## Workflow

### Step 1 — Detect discovery mode

1. Check project root:
   - No `constitution.md` / `docs/product.md`, or user prompt indicates new project ("create app", "new project", "choose stack") → **Greenfield App Mode**.
   - `constitution.md` or `docs/product.md` exists, or `--feature <slug>` passed → **Feature Architecture Mode**.
2. Monorepo check: read `@devflow/config.md`. If `## Apps` table present:
   - Validate `--app <name>` against table or prompt user with `AskQuestion`.
   - Scope architecture analysis to resolved app.

### Step 2 — Multi-axis problem analysis

Analyze the problem across six core architectural axes defined in `@devflow/skills/devflow-discover/references/discovery-axes.md`:

1. **Scope & Boundaries:** Core problem, primary actors, key user flows, edge cases, out-of-scope boundaries.
2. **Scale & Performance:** Concurrency, throughput, read/write ratio, latency budgets, real-time vs batch.
3. **Data & Consistency:** Entity relationships, persistence engine, ACID vs eventual consistency, state ownership.
4. **Integration Surface:** Touched services/modules, external APIs, protocols, breaking changes, blast radius.
5. **Security & Resilience:** Auth/authz, tenant isolation, failure modes, retries, fallback strategy.
6. **Operations & DX:** Team familiarity, operational burden, local development ergonomics, observability.

Read existing project context (`docs/product.md`, `constitution.md`, `registry.md`, adapter rules) and inspect code modules to identify established patterns and high-ambiguity axes.

### Step 3 — Interactive context-gathering Q&A loop

Formulate prioritized, high-leverage questions targeting the most critical or ambiguous axes identified in Step 2:

1. Cap question queue at **≤5 questions** — keep only high-impact architectural forks.
2. Ask questions one at a time using `AskQuestion` / `ask_question` tool:
   - State the architectural axis and why the decision matters.
   - Provide a **recommended answer** with concise technical rationale.
   - Offer bounded, distinct multiple-choice options when possible.
3. Synthesize user answers into confirmed **Decision Drivers & Constraints** before drafting options.

### Step 4 — Formulate 2–3 architectural options

Generate 2–3 distinct, viable architectural options grounded in the confirmed decision drivers:

1. **Architecture approach:** Component structure, communication pattern, state ownership, data flow.
2. **Key technologies / libraries:** Specific tools, protocols, storage mechanisms.
3. **Trade-off matrix:**
   - Complexity (low / medium / high)
   - Performance & scalability impact
   - Maintenance & cognitive load
   - Blast radius & migration risk
4. **Pros and Cons:** Concrete bullet points, no hand-waving.

### Step 5 — Interactive architecture selection

1. Present comparative options and trade-off matrix to user.
2. Recommend best option with concise technical rationale grounded in confirmed decision drivers.
3. Ask user to choose or adjust using `AskQuestion` tool (or chat prompt).
4. If minor sub-decisions remain (e.g. storage engine, auth provider), resolve with maximum 2 concise follow-up questions.
5. Confirm agreed architectural direction before writing files.

### Step 6 — Write Architecture Decision Record (ADR)

1. Determine ADR number:
   - Check `docs/adr/ADR-*.md`. Find highest 3-digit prefix (`NNN`).
   - If none exist, start with `001`. Next is `max + 1` zero-padded.
2. Create directory `docs/adr/` if missing.
3. Write `docs/adr/ADR-[NNN]-[title-slug].md` using template from `@devflow/skills/devflow-discover/references/adr-template.md`.
   - Record Multi-Axis Context Analysis, Decision Drivers, Considered Options (all 2–3), Decision Outcome, Consequences, Blueprint diagram, and Next Steps.
4. Update or create `docs/adr/README.md` index table with columns: `ADR | Title | Status | Date | Scope`.

### Step 7 — Pipeline handoff

- **Greenfield App Mode:**
  - If chosen stack matches an adapter (Angular, Flutter, Next.js, NestJS), instruct user:
    "Baseline architecture recorded in `docs/adr/ADR-[NNN]-[title-slug].md`. Run `/devflow.setup` to initialize project context and adapters."
- **Feature Architecture Mode:**
  - Instruct user:
    "Feature architecture recorded in `docs/adr/ADR-[NNN]-[title-slug].md`. Run `/devflow.task [feature idea]` (referencing this ADR) to start implementation pipeline."

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Skip discovery questions — infer context from prompt" | Inferred assumptions hide critical constraints. 2–3 targeted questions prevent costly architectural rework |
| "Skip discovery — pick familiar stack immediately" | Familiarity traps produce architectural debt. Compare alternatives against project constraints before locking in |
| "Only present one option to go faster" | One option is an ultimatum, not discovery. Minimum 2 distinct options required to expose trade-offs |
| "Write code prototype during discovery" | Discovery decides architecture and boundaries. Code before spec violates spec-first principle |
| "ADR is unnecessary bureaucracy for small decisions" | Undocumented decisions lead to architectural drift and repeated debates. ADR takes 2 minutes and preserves intent |

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Asking open-ended essay questions | Paralyzes user and produces vague answers | Use bounded multi-choice questions with a recommended option |
| Skipping multi-axis analysis | Misses critical non-functional constraints (scale, security, blast radius) | Systematically review the 6 discovery axes before formulating options |
| Monolithic option dumping | Overwhelms user with unformatted text | Use structured comparison table followed by focused `AskQuestion` |
| Skipping existing code inspection | Re-invents existing modules or violates constitution conventions | Read `constitution.md` and inspect codebase before proposing options |
| Leaving ADR in draft without user decision | Unresolved decisions stall downstream pipeline | Run interactive Q&A loop to reach explicit Accepted status |

## I/O Reference

| | |
| --- | --- |
| Reads | `docs/product.md`, `constitution.md`, `registry.md`, `devflow/config.md`, existing code modules |
| Reads (references) | `@devflow/skills/devflow-discover/references/discovery-axes.md`, `@devflow/skills/devflow-discover/references/adr-template.md` |
| Writes | `docs/adr/ADR-[NNN]-[title-slug].md`, `docs/adr/README.md` |
| Leads to | `devflow.setup` (greenfield app) or `devflow.task` (feature) |
