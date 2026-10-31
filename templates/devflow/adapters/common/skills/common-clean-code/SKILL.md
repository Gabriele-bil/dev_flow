---
name: common-clean-code
description: Enforce Clean Code, SOLID, and design principles across all technologies. Use when writing code, refactoring, designing architecture, or reviewing code quality.
---

# Skill: Clean Code

Stack-agnostic. Project decisions only — SOLID, code smells, YAGNI/KISS/DRY assumed known; apply them, do not restate them.

## Purpose

Project-wide code-quality rules every adapter shares: naming language, file size, duplication threshold, dependency direction. Read by `devflow.plan`, loaded by `devflow.implement` through adapter matrix rows.

## When NOT to Use

- File matches no row of the active adapter's `steps/implement.md` → skill load decision matrix that names this skill (plan reads it directly)
- Stack-specific structure (folders, layers, naming suffixes) — adapter `ADAPTER.md` + its skills win on conflict
- Generated code (`*.g.dart`, `*.freezed.dart`, OpenAPI clients, migrations) — never refactor by hand

## Rules

**Language:** English for identifiers, methods, properties, comments. Translate domain terms (`fattura` → `invoice`); user-facing copy stays in the product language via i18n.

**Naming (priority order):** consistent (same concept, same name everywhere) → domain language → specific (no `data`, `info`, `manager`, `helper`, `temp`) → brief → greppable.

**Size:**

- **Rule of 500:** file >500 lines → split; it has more than one reason to change.
- Function does one thing. Long function → extract when a block needs a comment to explain *what* it does. No fixed line or instance-variable cap — framework classes (components, notifiers, stores, services) legitimately hold several injected fields.

**Duplication:** Rule of Three — tolerate two copies; extract on the third. "A little duplication is cheaper than the wrong abstraction."

**Control flow:** early return over `else` after `return`/`throw`. Exhaustive `switch` over a sealed class / discriminated union is the preferred pattern; replace with polymorphism only when the same switch repeats in several places.

**Values:** magic numbers/strings → named constants. Wrap domain primitives (IDs, emails, amounts) in value objects or branded/typed wrappers when invalid values are possible.

**Comments:** say *why*, not *what*. Delete commented-out code.

**Dependencies:** point inward toward domain logic; infrastructure (HTTP, DB, SDKs) depends on domain, never reverse. Inject dependencies; depend on an abstraction only where a second implementation or a test fake exists.

**Features:** vertical slices — one feature folder owns its UI, state, data. Code moves to the shared folder only once a second feature needs it.

## Red Flags

| Flag | Fix |
| --- | --- |
| File >500 lines | Split by responsibility |
| Abstraction before third duplication | Inline until Rule of Three |
| Interface with one implementation and no test fake | Use concrete class |
| Code for a requirement not in `plan.md` | Delete (YAGNI) |
| Domain imports framework/HTTP/DB package | Move behind repository/port |
| Non-English identifier | Rename |
| Same `switch` on type in 3+ places | Polymorphism or one mapping function |

## I/O Reference

| | |
| --- | --- |
| Reads | Source files being written, refactored or reviewed |
| Writes | Nothing — rules applied to code produced by the invoking step |
| Invoked by | `devflow.plan` (always); `devflow.implement` via adapter `steps/implement.md` matrix rows |
| Related skills | `common-state-patterns` (state scope decisions) |
