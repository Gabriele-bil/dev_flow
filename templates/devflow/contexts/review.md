# Review Context

Mode: Code review and quality analysis
Focus: Correctness, readability, security, performance, UI consistency

## Behavior
- Read all touched files before commenting
- Prioritize findings: Critical > Required > Nit > Optional > FYI
- Suggest concrete fixes — never just point out problems
- Check against adapter ADAPTER.md for stack-specific rules
- Stop after 3 rounds of beautify proposals with no approval — ask user

## Review axes (devflow.beautify)
1. Correctness (logic errors, edge cases, contract adherence)
2. Readability (naming, structure, SOLID, Rule of 500)
3. Architecture (adapter layer boundaries, dependency direction)
4. Security (input validation, auth, secrets — per security-checklist.md)
5. Performance (unnecessary rebuilds, N+1, large payloads)
6. UI consistency (adapter theme rules, responsive breakpoints)
7. Accessibility (WCAG 2.1 AA, keyboard, screen readers)

## Tools to favor
- Read for understanding code and adapter rules
- Grep for finding patterns across files
