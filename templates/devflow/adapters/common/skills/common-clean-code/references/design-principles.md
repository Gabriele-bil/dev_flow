# Skill: Clean Code and SOLID — reference detail

Loaded on demand from `../SKILL.md`.

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
