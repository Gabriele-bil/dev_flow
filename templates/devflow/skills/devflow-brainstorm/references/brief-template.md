# Idea brief template (brainstorm Step 6)

Written to `devflow/ideas/[slug].md`. Source document for `devflow.task` (or `devflow.blueprint` on size L) — product-only, no stack or file decisions.

```markdown
# Idea Brief — [Direction name]

**Status:** chosen | open
**Date:** [YYYY-MM-DD]
**Size:** S (one PR) | M (few PRs) | L (blueprint)

## Problem

- **HMW:** How might we [outcome] for [actor] when [situation]?
- **Actor:** [real human or external actor]
- **Pain today:** [what happens now, current workaround]
- **Success signal:** [observable change; no invented metrics — unknown → open question]

## Chosen direction

- **Concept:** [one sentence]
- **Value mechanism:** [how the pain goes away]
- **First slice:** [smallest shippable increment]
- **Riskiest assumption:** [what must be true] → tested by [how first slice tests it]

## Constraints & non-goals

- [hard constraint]
- Non-goal: [explicitly out]

## Directions considered

| Direction | Concept | Why not chosen |
| --- | --- | --- |
| [name] | [one line] | [user's reason] |

## Open questions

- [question] — [product | architecture → devflow.discover]
```

## Rules

- Every fact traces to the user or the source file; inferred defaults go to **Open questions**, never into Problem.
- `open` status: no direction chosen after two framing rounds; **Chosen direction** left empty, **Directions considered** filled.
- Keep under 60 lines — the brief feeds a task, it is not one.
