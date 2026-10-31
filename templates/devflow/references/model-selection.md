# Model Selection Guide

Where each pipeline step runs, and with which model and effort. One table — skill and agent frontmatter must match it (`scripts/validate-skills.sh --strict` rejects `model:` on a core skill).

## Rules

- **Main context runs on the session model.** A `model:` on a skill is a model switch for that turn: the next request re-reads the whole conversation with no cache hits, which on a long session costs more than a smaller model saves. Core skills set only `effort` — on Opus 5.5, Sonnet 5.5, Haiku 5.5 and Fable 5.1 an effort change keeps the cache.
- **A different model means a subagent.** Subagents have their own context and cache, so their model never touches the main conversation's cache: ship's reviewers (`agents/*.md`) and the `step-runner` that `devflow.run` / `devflow.auto` dispatch per step.
- **Aliases only** (`opus`, `sonnet`, `haiku`, `fable`), never full model IDs — they follow the current model generation and the provider. The Agent tool's per-call `model` takes the same aliases.
- **Antigravity CLI:** the build strips `model`, `effort`, `maxTurns` and `experimental`; every step and agent runs on the session model. Per-step quality there comes from the skills and scripts, not from model choice.

## Decision Table

| Step | Interactive (main context) | `devflow.run` / `devflow.auto` | Effort |
| --- | --- | --- | --- |
| `devflow-task` | session model | step-runner, `sonnet` | medium |
| `devflow-clarify` | session model | — (interactive only) | low |
| `devflow-plan` | session model | step-runner, `sonnet` (`thorough`: `opus`) | high |
| `devflow-analyze` | session model | step-runner, `sonnet` | low |
| `devflow-implement` | session model | step-runner, `sonnet` (`thorough`: `opus`) | medium |
| `devflow-beautify` | session model | step-runner, `sonnet` | medium |
| `devflow-test` | session model | step-runner, `sonnet` | medium |
| `devflow-ship` | session model — orchestrates the fan-out (subagents cannot dispatch subagents) | same, in the orchestrator's context | medium |
| `devflow-pr` | session model | orchestrator's context | low |
| `devflow-blueprint`, `devflow-init` | session model | — | high |

Skills not listed run on the session model with the effort in their frontmatter (or the session's).

**Ship reviewers** (`agents/*.md`, `maxTurns: 40`, `experimental.cacheTtl: 1h` so Step 4b re-runs hit the cache):

| Agent | Model | Effort | `thorough` profile |
| --- | --- | --- | --- |
| `code-reviewer` | `sonnet` | high | per-call `model: opus` |
| `security-auditor` | `sonnet` | high | per-call `model: opus` |
| `test-engineer` | `sonnet` | medium | — |
| `accessibility-auditor` | `sonnet` | medium | — |
| `docs-reviewer` | `sonnet` | low | — |

Never below `sonnet` for ship reviewers — `hooks/pre-model-switch.sh` blocks the switch.

## Subtask & Slice Routing Tiers (`[route: light | mid | strong]`)

In `plan.md` and `devflow.blueprint`, individual slices or File List entries can declare a routing tier so expensive models only build what requires judgment. A tier applies when the slice runs in a subagent (step-runner, or a slice dispatched by `devflow.implement`), as that call's `model`; in the main context it is a hint only.

| Tier | Subagent model | When to Use | Mandatory Brief Gate |
| --- | --- | --- | --- |
| `light` | `haiku` | Mechanical work: wiring a field across 2–3 files, adding a CLI/switch case next to an existing one, writing a test for a stated case, renaming | Must have all 4 brief parts (`Change`, `Contract`, `Test`, `Out of scope`) + exact test command; refuse `light` routing if brief requires design judgment |
| `mid` | `sonnet` | Standard feature slice, UI component with state, bug fix with known cause | Standard `plan.md` File List entry + mapped AC |
| `strong` | `opus` | Shared contracts (`Slice 1`), DB migrations, auth/security boundaries, subtle concurrency or edge trade-offs | Full architectural context + ADR alignment |

**Auto-escalation rule:** When a subagent or slice running on `light` or `mid` hits Level 1 retry exhaustion (`escalation-ladder.md`), escalate the slice one tier up (`light → mid → strong`) before entering Level 3/4 re-planning.

## Depth profile hints

`plan.md` `**Complexity:**` (see `references/complexity-scoring.md`) only changes the subagent models marked `thorough` above and the ship fan-out size. `quick` never lowers ship reviewers below `sonnet`; security-touching features stay at `standard`+ (profile floor in `complexity-scoring.md`).

## Anti-Patterns

| Anti-Pattern | Problem |
| --- | --- |
| `model:` on a core skill | Model switch on every invocation → full cache miss on the main conversation |
| Opus for every step | 5–10× cost with no quality gain on mechanical tasks |
| Haiku for devflow.ship agents | Security misses on cost optimization = false confidence |
| Full model IDs in frontmatter | Break on the next model generation and on other providers |
| Upgrading model to "fix" logic errors | Model is rarely the problem; debug prompt/context first |

## Setting it in frontmatter

```yaml
# skills/devflow-plan/SKILL.md — main context: effort only
effort: high

# agents/code-reviewer.md — subagent: model, effort, turn cap, 1h cache
model: sonnet
effort: high
maxTurns: 40
experimental:
  cacheTtl: 1h
```
