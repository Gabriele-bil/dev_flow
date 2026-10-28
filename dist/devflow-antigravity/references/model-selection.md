# Model Selection Guide

Stack-agnostic. Use alongside skill frontmatter `model:` field.
Select model based on task complexity and cost budget — not habit.

## Decision Table

| Pipeline Step | Recommended | Fallback | Rationale |
| --------------- | ------------- | ---------- | ----------- |
| `devflow-task` | Haiku | Sonnet | exploration + HMW framing; fast iteration |
| `devflow-plan` | Sonnet | Opus | multi-file reasoning, dependency ordering |
| `devflow-implement` | Sonnet | Opus | coding across multiple files; context budget matters |
| `devflow-beautify` | Haiku | Sonnet | localized refactoring; single-file scope |
| `devflow-test` | Sonnet | Opus | test generation with coverage gap analysis |
| `devflow-ship` (agents) | Opus | Sonnet | security + correctness review; cannot miss issues |
| `devflow-pr` | Haiku | Sonnet | mechanical git operations; no reasoning required |
| `devflow-recovery` | Sonnet | Opus | diagnosis requires multi-file state read |

## Model Profiles

### Haiku

- Use for: single-file edits, search, formatting, git commands, notifications
- Avoid for: architecture decisions, security review, cross-file reasoning
- Cost: lowest; fastest

### Sonnet

- Use for: multi-file implementation, planning, test generation, code review
- Default for most pipeline steps
- Cost: balanced; reliable

### Opus

- Use for: security audit, architecture decisions, unresolvable implement loops
- Use when: accuracy cannot be sacrificed (devflow.ship security-auditor, code-reviewer)
- Cost: highest; slowest — reserve for critical review steps

## Depth Profile Hints

Depth profile from `plan.md` `**Complexity:**` tag (see `references/complexity-scoring.md`) shifts the Decision Table:

| Profile | implement | beautify | test | ship agents |
| --------- | ----------- | ---------- | ------ | ------------- |
| `quick` | Haiku/Sonnet | Haiku | Haiku | Sonnet (`code-reviewer` only) |
| `standard` | Decision Table above | — | — | — |
| `thorough` | Sonnet/Opus | Sonnet | Sonnet | Opus (all 5 agents) |

Never downgrade ship security review below the Decision Table for cost — profile floor in `complexity-scoring.md` keeps security-touching features at `standard`+.

## Subtask & Slice Routing Tiers (`[route: light | mid | strong]`)

In `plan.md` and `devflow.blueprint`, individual slices or File List entries can declare a routing tier so expensive models only build what requires judgment:

| Tier | Target Model | When to Use | Mandatory Brief Gate |
| --- | --- | --- | --- |
| `light` | Haiku / Flash | Mechanical work: wiring a field across 2–3 files, adding a CLI/switch case next to an existing one, writing a test for a stated case, renaming | Must have all 4 brief parts (`Change`, `Contract`, `Test`, `Out of scope`) + exact test command; refuse `light` routing if brief requires design judgment |
| `mid` | Sonnet | Standard feature slice, UI component with state, bug fix with known cause | Standard `plan.md` File List entry + mapped AC |
| `strong` | Opus / Sonnet-high | Shared contracts (`Slice 1`), DB migrations, auth/security boundaries, subtle concurrency or edge trade-offs | Full architectural context + ADR alignment |

**Auto-escalation rule:** When a subagent or slice running on `light` or `mid` hits Level 1 retry exhaustion (`escalation-ladder.md`), escalate the slice one tier up (`light → mid → strong`) before entering Level 3/4 re-planning.

## Anti-Patterns

| Anti-Pattern | Problem |
| --- | --- |
| Opus for every step | 5–10× cost with no quality gain on mechanical tasks |
| Haiku for devflow.ship agents | Security misses on cost optimization = false confidence |
| No model declared in skill frontmatter | Inherits caller model — unpredictable behavior across environments |
| Upgrading model to "fix" logic errors | Model is rarely the problem; debug prompt/context first |

## Setting Model in Skill Frontmatter

```yaml
---
name: devflow-ship
description: Pre-merge quality gate
model: claude-opus-4-7
---
```

Field is optional — omit if inheriting from session default is acceptable.
Adapter skills: inherit from pipeline step that invokes them; explicit override only if cost-sensitive.
