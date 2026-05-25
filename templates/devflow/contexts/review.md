# Review Context

Mode: Code review and quality analysis
Focus: Correctness, readability, security, performance, UI consistency

## Behavior
- Read all touched files before commenting
- Suggest concrete fixes — never just point out problems
- Check against adapter ADAPTER.md for stack-specific rules

## Scope
- Analyze **only** files touched by the current devflow.implement run
- Do not expand scope to unrelated files
- Do not refactor pre-existing code outside the implement summary

## Severity labels

| Prefix | Meaning | Action |
|--------|---------|--------|
| **Critical:** | Security risk, wrong behavior vs plan, data loss risk | Must fix before beautify is done |
| *(none)* | Required | Fix before merge |
| **Nit:** | Minor style preference | Optional |
| **Optional:** / **Consider:** | Suggestion | Worth doing; not required |
| **FYI:** | Context only | No code change required |

## Review axes
1. Correctness (logic errors, edge cases, contract adherence, acceptance criteria)
2. Readability (naming, structure, SOLID, Rule of 500, simplifications)
3. Architecture (adapter layer boundaries, dependency direction, import conventions)
4. Security (input validation, auth, secrets — per security-checklist.md)
5. Performance (unnecessary rebuilds, N+1, large payloads, hot-path recreation)
6. UI consistency (adapter theme rules, design-system tokens, no hardcoded styles)
7. Accessibility (WCAG 2.1 AA, keyboard, screen readers, focus management)
8. Responsiveness and layout (required breakpoints, adaptive branching, no raw viewport literals)

## Stall-out rule
After 3 consecutive proposal rounds with no user approval on **any** item, stop and emit:

```
⚠️ Beautify stalled: [N] proposals pending without approval.
Options: (1) approve all remaining, (2) skip all remaining, (3) continue one by one
```

Wait for user choice before continuing.

## Tools to favor
- Read for understanding code and adapter rules
- Grep for finding patterns across files
- Edit for applying approved fixes
