# Plan file template

Used by `devflow.plan` Step 5 — write `devflow/features/[NNN]_[feature-name]/plan.md` using this format.

```markdown
# Plan - [Feature Name]

**ID:** PLAN-[NNN]
**Task:** [link to task.md]
**Date:** [YYYY-MM-DD]
**Status:** ready
**Complexity:** [N] ([quick | standard | thorough])

---

## Overview

[3-5 sentences. What this feature does, how it fits the architecture,
and any non-obvious implementation decisions. If subtasks are layer-shaped,
state the vertical-slice execution order here.]

---

## Architecture decisions

- **[Decision title]**: [One-line rationale.]
- [2-5 bullets total; omit only if truly trivial]

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk] | High / Med / Low | [Concrete mitigation] |

[Use 2-4 rows for non-trivial work; one row acceptable for small plans.]

---

## Open questions

[Omit this entire section if `task.md` is `ready` and there are no planning blockers.]

- [ ] [Question — resolve before `devflow.implement` or update `task.md`.]

---

## Traceability

| Subtask | Acceptance criteria | File(s) |
|---------|---------------------|---------|
| [Subtask description from task.md] | [acceptance criterion from task.md] | [file path(s)] |
| ... | ... | ... |

---

## File List

Ordered by implementation sequence. Each file must be implemented
in this order to respect dependencies.

**Batch hints (optional):** Before the first `###` of a dependency group, add one line:
`**Batch:** S | M | L` (S ≈ 1-2 files, M ≈ 3-5, L ≈ 6+). For `L`, add `— split across `devflow.implement` sessions if needed`.

**Parallelism markers (optional):** Mark parallelizable leaf files with a `[P]` prefix on the entry line. A file is `[P]`-eligible only when: (1) no other `[P]` file in the same batch touches it, and (2) it does not modify shared contracts, migrations, or state-management contracts. `[P]` coexists with `[pending]`/`[done]` — `[P]` = parallelism potential, status markers = completion state. Do not mark files that touch shared contracts, migrations, or state-management contracts.

### [NNN]. `[path/to/file.ext]` - [create | modify] [pending]
[1-2 sentences on what this file contains and why it exists.]

### [NNN]. [P] `[path/to/file.ext]` - [create | modify] [pending]
[`[P]` present: file is eligible for parallel implementation by a separate agent or session.]
...

---

## Implementation checkpoints

[For trivial 1-2 file plans, omit this section or use a single checkpoint.]

- **After [milestone / batch]:** use verification commands from `ADAPTER.md` (e.g. analyze / test); add short manual smoke if relevant
- [2-4 checkpoints for larger plans]

---

## Adapter-specific sections

After **Implementation checkpoints**, append **every extra plan section** required by the active `ADAPTER.md` (see its heading **Plan: extra sections and templates**). Use the exact headings and table formats from that file. Omit adapter sections only when `ADAPTER.md` says they do not apply.

---

## Edge Cases & Error Handling

- **[Scenario]**: [how it is handled]
- **[Scenario]**: [how it is handled]

---

## Pre-implement checklist

- [ ] Constitution Gate passed (Step 0b) — no Critical violations
- [ ] Every `task.md` subtask appears in **Traceability** with its acceptance criterion
- [ ] Every **File List** entry maps to ≥1 **Traceability** row — no orphan/gold-plated files
- [ ] **File list** order respects **Dependency ordering** (and any stated exceptions)
- [ ] All **adapter-specific sections** from `ADAPTER.md` are present or correctly omitted per adapter rules (e.g. i18n keys for UI)
- [ ] **Implementation checkpoints** are actionable (commands per `ADAPTER.md` — analyze / tests / smoke)
- [ ] **Open questions** are empty or resolved if **Status** is `ready`
- [ ] Existing shared components checked; no duplication of a component already in `shared/`
- [ ] New reusable components identified in this plan are listed under their `shared/` path in the **File List**
- [ ] `devflow.analyze` run (or explicitly waived) — no Critical findings
- [ ] If feature touches persistent entities → `data-model.md` exists and is non-empty
- [ ] `**Complexity:**` recorded per `references/complexity-scoring.md` — profile floor applied (auth/migrations/input → minimum `standard`)
```

Format rules:

- Adapter-specific sections: follow `ADAPTER.md` layout exactly (optional/required blocks, localization/data rules).
- Language: English.
- Compression: caveman-compress — drop articles/filler/hedging; keep technical terms/paths/commands exact.
