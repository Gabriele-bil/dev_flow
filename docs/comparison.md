# DevFlow vs Alternatives

Honest positioning against the three closest alternatives: [Forge](https://github.com/LucasDuys/forge), [GitHub spec-kit](https://github.com/github/spec-kit), and vanilla Claude Code (no plugin). A fuller Forge analysis with transposition proposals lives in [`forge-gap-analysis.md`](forge-gap-analysis.md).

## At a glance

| Dimension | DevFlow | Forge | spec-kit | Vanilla Claude Code |
| --- | --- | --- | --- | --- |
| Driver | User-gated: you invoke each step | Self-prompting loop: Stop hook re-prompts until done | User-gated commands | You, ad hoc |
| Runtime | Markdown + bash/jq, no engine | Node.js engine + JS hooks | CLI (Python) + templates | none |
| Spec format | task.md: HMW, scope, subtasks, ACs + traceability table in plan.md | R-numbered requirements with testable ACs | spec.md + plan.md + tasks.md | none enforced |
| Stack awareness | **Adapters** (Flutter/Angular/Next.js): commands, tech skills, per-step checklists | generic | generic (constitution file) | generic |
| Verification | Tests + goal-backward per-AC verification + multi-agent ship gate | Goal-backward 4-level verifier + reviewer loop | checklist-driven, manual | whatever you ask for |
| Spec feedback loop | `devflow.backprop` + instincts log | backprop phase + gap patterns | none | none |
| Failure handling | Bounded escalation ladder (retry → debug → re-approach → block) | 7-level circuit breakers incl. cross-model rescue | none | none |
| Recovery/resume | state machine + `devflow.resume` / `devflow.recovery` | on-disk state machine, checkpoints, forensic rebuild | none | compaction summary only |
| Multi-machine collaboration | none | claim leases, flags, transports | none | none |
| Hosts | Claude Code, Cursor, Antigravity | Claude Code | Copilot, Claude Code, Gemini, Cursor + | Claude Code |

## Where each wins

**Pick Forge if** you want overnight autonomy. Its self-prompting loop, per-task worktrees, budget phases, and 745-test engine are built for "kick off at midnight, read diffs at breakfast". The cost: a Node runtime, single-host, and much less human control mid-flight. DevFlow deliberately keeps gates at every step — its autonomy story is thinner by design.

**Pick spec-kit if** you want a lightweight, host-agnostic spec convention with minimal machinery. It standardizes *artifacts* (spec → plan → tasks) but leaves quality gates, stack rules, failure handling, and state management to you.

**Stay vanilla if** the project is a script, a spike, or a one-file fix. Any pipeline is overhead when the change is smaller than the ceremony — DevFlow's own skills say as much in their "When NOT to Use" sections.

**Pick DevFlow if** you work across Flutter/Angular/Next.js codebases and want the agent held to *your stack's* rules, with explicit human gates and mechanical traceability from idea to PR. Its distinctive combination:

- **Adapters** — the only one of the four with per-stack contracts (commands, technology skills loaded by file-path trigger, per-step checklists).
- **Traceability as an enforcement tool, not documentation** — the subtask → AC → file table is what makes goal-backward verification and backprop nearly free.
- **Layered gates** — beautify (multi-axis), test (+ per-AC verification), ship (parallel specialist agents incl. scope-fidelity/anti-over-engineering review).
- **Self-testing plugin** — structural lint plus deterministic trigger/collision evals on the skills themselves.
- **No runtime** — auditable markdown and shell; works on three hosts.

## Trade-offs we accept

- **Ceremony is mostly fixed-cost** — a one-line fix pays more overhead than it should (depth profiles are on the roadmap; Forge already scales rigor by complexity score).
- **Gates cost wall-clock time** — you approve steps Forge would chain through autonomously. That's the point, but it's real friction.
- **No multiplayer** — Forge's claim-lease collaboration has no DevFlow equivalent.
- **Hook logic is lightly tested** — Forge's engine has an order of magnitude more self-tests than DevFlow's hook scripts.
