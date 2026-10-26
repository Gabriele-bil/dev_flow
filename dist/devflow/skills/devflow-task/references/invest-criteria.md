# INVEST Criteria & Definition of Ready

Guidance for evaluating user stories and tasks in DevFlow. Based on Bill Wake's INVEST model.

## The 3 C's Model

A user story operates across three dimensions:

- **Card**: Compact reminder of user need — not a rigid contract.
- **Conversation**: Collaborative dialog between product and engineering to unpack requirements.
- **Confirmation**: Concrete acceptance criteria (BDD Gherkin) defining when the story is done.

## INVEST Criteria

### I — Independent

- Story should be self-contained and deliverable on its own.
- Avoid artificial blocking dependencies between parallel stories.
- When two stories are tightly coupled, merge them or redraw boundaries along a different vertical axis.

### N — Negotiable

- Captures *what* problem to solve and *why*, leaving implementation *how* to `devflow.plan`.
- Avoid premature architectural lock-in or prescribing rigid UI details in the story card.

### V — Valuable

- Delivers an end-to-end slice of working software providing observable value to an actual user or business.
- Never write horizontal technical stories (e.g., "create DB table", "build backend endpoint"). Every story touches necessary layers end-to-end.

### E — Estimable

- Scope and requirements are clear enough for engineering to plan with confidence.
- When high technical uncertainty or unknown third-party APIs prevent estimation, break out a time-boxed **Spike** task first.

### S — Small

- Sized for rapid implementation within a single iteration/sprint.
- Slicing tactics: split by workflow step, business rule variation, data variation, or separate read from write operations.

### T — Testable

- Acceptance criteria must be objective, observable, and falsifiable.
- Non-functional requirements (performance, accessibility) must be quantified (e.g., "LCP < 2.0s"), never stated as vague adjectives.

## Definition of Ready (DoR) Gate

Before moving from `devflow.task` to `devflow.plan`, verify:

1. Persona is an actual human user or distinct external system actor.
2. Goal articulates clear business/user outcome without tautology.
3. Use cases cover happy path plus at least one edge/error flow.
4. Acceptance criteria use strict BDD Gherkin (1 `When` per scenario).
5. Asynchronous operations have explicit loading, success, and error behaviors.
6. Zero implementation leaks (no classes, database tables, or framework names).
