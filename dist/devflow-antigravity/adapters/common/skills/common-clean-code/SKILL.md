---
name: common-clean-code
description: Enforce Clean Code, SOLID, and design principles across all technologies. Use when writing code, refactoring, designing architecture, or reviewing code quality.
---

# Skill: Clean Code and SOLID

Stack-agnostic. Apply when writing, refactoring, or reviewing any code.

## Purpose

Produce code easy to discover, understand, change, debug, and deploy. Testable, maintainable, reduces long-term cost.

## Language

English for all identifiers, methods, properties, comments. Translate local terms.

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
- Comments = "why". Code = "what". Delete redundant comments.
- No `else` when early return works. Reduce nesting.
- Keep entities small (< 50 lines for classes, < 10 for methods).
- **Rule of 500:** >500 lines → split (single-responsibility signal).

**Value objects:** wrap domain primitives (IDs, emails, amounts). Expose only valid states.

## SOLID Principles

| Principle                       | Question                                        | Action                          |
| ------------------------------- | ----------------------------------------------- | ------------------------------- |
| **SRP** — Single Responsibility | "Does this have ONE reason to change?"          | Split large classes/files       |
| **OCP** — Open/Closed           | "Can I extend without modifying?"               | Use interfaces and abstractions |
| **LSP** — Liskov Substitution   | "Can subtypes replace base types safely?"       | Remove unimplemented methods    |
| **ISP** — Interface Segregation | "Are clients forced on unused methods?"         | Split fat interfaces            |
| **DIP** — Dependency Inversion  | "Do high-level modules depend on abstractions?" | Inject dependencies             |

## Reference detail

Detail for Design: Four Elements of Simple Design, Design: Complexity Management, Design: Object Roles, Design: Behavioral Principles, Design: Architecture: [references/design-principles.md](references/design-principles.md) — load when touching those areas.

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
- Hardcoded values that belong in constants
- Abstraction added before the third duplication
- Speculative code added without a current requirement
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
