---
name: common-clean-code
description: Enforce Clean Code, SOLID, and design principles across all technologies. Use when writing code, refactoring, designing architecture, or reviewing code quality.
---

# Skill: Clean Code and SOLID

Stack-agnostic. Apply when writing, refactoring, or reviewing any code.

## Purpose

Produce code easy to discover, understand, add, change, remove, debug, and deploy. Testable, flexible, maintainable code reduces long-term cost.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## Language

All identifiers, methods, properties, and comments use English. Universal readability. Translate local terms.

## Clean Code

**Naming (priority order):**

1. **Consistent** — same concept, same name everywhere
2. **Understandable** — domain language, not technical jargon
3. **Specific** — precise over vague (avoid `data`, `info`, `manager`, `temp`)
4. **Brief** — short but not cryptic
5. **Searchable** — unique, greppable names

**Structure:**

- Methods do one thing. Isolate bugs. Extract long methods.
- Magic numbers move to constants. Prevent errors. Define `const`/`final`/`static`.
- Variables reveal intent. Self-documenting code. Rename vague variables.
- Comments explain "why". Code explains "what". Delete redundant comments.
- No `else` when early return works. Reduce nesting.
- Keep entities small (< 50 lines for classes, < 10 for methods).
- **Rule of 500:** file over 500 lines → split. Single-responsibility breakdown signal.

**Value objects:** wrap domain primitives (IDs, emails, amounts) in typed objects. Prevent misuse. Expose only valid states.

## SOLID Principles

| Principle                       | Question                                        | Action                          |
| ------------------------------- | ----------------------------------------------- | ------------------------------- |
| **SRP** — Single Responsibility | "Does this have ONE reason to change?"          | Split large classes/files       |
| **OCP** — Open/Closed           | "Can I extend without modifying?"               | Use interfaces and abstractions |
| **LSP** — Liskov Substitution   | "Can subtypes replace base types safely?"       | Remove unimplemented methods    |
| **ISP** — Interface Segregation | "Are clients forced on unused methods?"         | Split fat interfaces            |
| **DIP** — Dependency Inversion  | "Do high-level modules depend on abstractions?" | Inject dependencies             |

## Design: Four Elements of Simple Design

Priority order:

1. **Runs all tests** — must work correctly
2. **Expresses intent** — readable, reveals purpose
3. **No duplication** — DRY after Rule of Three (wait for 3 occurrences)
4. **Minimal** — fewest classes and methods needed

## Design: Complexity Management

**Essential complexity** = inherent to the problem domain. **Accidental complexity** = introduced by the solution.

Detect complexity via:

- Change amplification — small change requires many files
- Cognitive load — hard to understand without context
- Unknown unknowns — surprising or hidden behavior

Fight with:

- **YAGNI** — don't build for hypothetical future needs
- **KISS** — simplest solution that works
- **DRY** — but only after Rule of Three

## Design: Object Roles

| Stereotype         | Role                                  |
| ------------------ | ------------------------------------- |
| Information Holder | Holds data, minimal behavior          |
| Structurer         | Manages relationships between objects |
| Service Provider   | Performs work, stateless operations   |
| Coordinator        | Orchestrates multiple services        |
| Controller         | Makes decisions, delegates work       |
| Interfacer         | Transforms data between systems       |

## Design: Behavioral Principles

- **Tell, Don't Ask** — command objects; do not query then decide
- **Law of Demeter** — only talk to immediate collaborators; one dot per line
- **Hollywood Principle** — invert control; let the framework call you

## Design: Architecture

- Dependencies point inward toward domain. Infrastructure depends on domain; never reverse.
- Features are vertical slices — end-to-end, self-contained.
- Layers do not expose internal details to each other.

## Code Smells

| Smell                  | Fix                                |
| ---------------------- | ---------------------------------- |
| Long Method            | Extract methods                    |
| Large Class            | Extract class, apply SRP           |
| Long Parameter List    | Introduce parameter object         |
| Primitive Obsession    | Wrap in value objects              |
| Feature Envy           | Move method to envied class        |
| Speculative Generality | Remove unused abstractions (YAGNI) |
| Switch Statements      | Replace with polymorphism          |
| Data Clumps            | Extract class for grouped data     |
| Divergent Change       | Split into focused classes         |
| Shotgun Surgery        | Move related code together         |

## Red Flags

Stop and rethink when:

- Class has more than 2 instance variables
- Method longer than 10 lines
- More than one level of indentation
- Using `else` when early return works
- Hardcoded values that should be constants
- Abstraction added before the third duplication
- Feature added "just in case"
- Depending on concrete implementations over abstractions
- God class that orchestrates everything

> "A little duplication is 10× better than the wrong abstraction."

## I/O Reference

|                |                                                            |
| -------------- | ---------------------------------------------------------- |
| Trigger        | Code creation, refactoring, PR review, architecture design |
| Reads          | All source files                                           |
| Invoked by     | `devflow.plan`, `devflow.implement`, `devflow.beautify`    |
| Related skills | None                                                       |
