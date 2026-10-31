---
name: devflow-analyze
description: "Read-only check: task.md+plan.md+constitution.md+ADRs consistency. Flags traceability gaps, untestable ACs, terminology drift, layer violations, ADR misalignment. Use when user runs devflow.analyze — after devflow.plan (ready), before devflow.implement."
argument-hint: "[optional-feature-path]"
effort: low
disallowed-tools: Write, Edit, NotebookEdit
---

# Skill: devflow.analyze

**Arguments:** `$ARGUMENTS` — empty → resolve the feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask the user).

## Purpose

Read-only cross-artifact consistency check. Verify `task.md` and `plan.md` are internally consistent and constitution-compliant before implementation begins. Run between `devflow.plan` (Status: ready) and `devflow.implement`.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## When NOT to Use

- `plan.md` does not exist or its Status is not `ready` — run `devflow.plan` first
- Implementation already in progress — analyze applies to pre-implement state only; use `devflow.beautify` post-implement
- You need interactive resolution of findings — use `devflow.clarify` for `[NEEDS CLARIFICATION: ...]` markers; edit artifacts manually for traceability gaps

## Input contract

Before running, verify:

- [ ] `task.md` exists at `devflow/features/[NNN]_[feature-name]/task.md`
- [ ] `plan.md` exists at `devflow/features/[NNN]_[feature-name]/plan.md`
- [ ] `plan.md` Status is `ready`

If any item fails → stop, report which check failed, do not run analysis passes.

## Workflow

### Step 1 — Load artifacts

Read in order:

1. `devflow/features/[NNN]_[feature-name]/task.md` — extract: use case / subtask list, acceptance criteria list
2. `devflow/features/[NNN]_[feature-name]/plan.md` — extract: Traceability table (use case / subtask → AC → file(s)), File List (paths + status), Architecture decisions
3. `constitution.md` — extract: layer ordering rules and naming conventions
4. `docs/adr/` (if referenced in `task.md`/`plan.md` or `docs/adr/README.md` exists) — extract accepted architectural decisions, rejected alternatives, and boundaries

If no path is provided, resolve feature with `bash "@devflow/scripts/devflow-state.sh" resolve` (exit 1 → ask).

### Step 2 — Run 7 detection passes

Run all passes independently and collect findings. Do not stop after the first failing pass — produce a complete report. Skip `task.md` rows explicitly marked `[wont]` or `[retired]` (verify they are not cited in `plan.md` Traceability).

---

#### Pass A — Traceability completeness

**Goal:** every `task.md` use case / subtask has at least one row in the Traceability table with a non-empty file path.

For each use case / subtask in `task.md`:

- Find corresponding rows in `plan.md` Traceability table (match by UC title or subtask description).
- No row found → **Critical**: use case / subtask not covered in Traceability.
- Row found but file path is empty or `—` → **Critical**: use case / subtask row has no file mapping.

---

#### Pass B — Acceptance criteria testability

**Goal:** every AC is observable and falsifiable.

For each acceptance criterion in `task.md`:

- Flag if it uses untestable language or *importance without mechanism*: "works correctly", "looks good", "behaves as expected", "is user-friendly", "performs well", "is fast", "is clean", "is easy to use", "is robust", "is seamless", "is comprehensive", "handles edge cases".
- Flag if it relies on *specific-looking vagueness* (ungrounded claims without a concrete trigger, actor, or threshold).
- Flag if it describes internal implementation state instead of externally observable behavior (e.g. "the class exposes a method…", "writes to table X", "returns 401").
- Flag if scenario bundles multiple actions (`When ... And ...` chained triggers) — must follow the single `When` rule.
- Severity: **Required** — untestable or compound AC blocks `devflow.test` from writing meaningful assertions.
- Suggested format: BDD Gherkin phrasing (`GIVEN [context] WHEN [single action] THEN [observable outcome]`) per `devflow-task/references/bdd-acceptance-criteria.md`, or EARS phrasing (`WHEN [trigger] THE SYSTEM SHALL [response]`).

---

#### Pass C — Terminology consistency

**Goal:** same concept uses the same term in both `task.md` and `plan.md`.

Build a term inventory from both documents. For each conceptual entity (feature name, actor, module, entity, field name), check whether multiple synonyms appear across the two documents.

Flag pairs such as "user profile" / "profile page" / "account page" when they refer to the same concept.

- Severity: **Nit** for minor style divergence; **Required** when divergence crosses a domain boundary (e.g. the same database entity is named differently across `task.md` and `plan.md` Architecture decisions).

---

#### Pass D — Constitution alignment

**Goal:** each file path in the File List follows the layer rules in `constitution.md`.

For each entry in `plan.md` File List:

- Extract the directory segment of the path.
- Check it against the layer hierarchy and naming conventions declared in `constitution.md`.
- Flag paths that place a file in a layer that violates declared ordering or naming conventions.
- Severity: **Critical** — layer violations are flagged by `devflow.beautify` and cause compile or lint failures.

---

#### Pass E — Coverage balance

**Goal:** no AC maps to 0 files; no file in File List has 0 Traceability rows.

- For each AC in `task.md`: count files linked to it in Traceability. If 0 → **Required**: AC has no implementation mapping.
- For each file in File List: count Traceability rows that reference it. If 0 → **Required**: file is orphaned — not traced to any subtask or AC.

---

#### Pass F — ADR alignment (conditional)

**Trigger:** `docs/adr/` exists or `task.md`/`plan.md` contains an `**ADRs:**` reference.

**Goal:** `plan.md` Architecture decisions and File List do not contradict accepted decisions in active ADRs.

- Scan referenced ADRs (or active ADRs in `docs/adr/`) for Accepted decisions, rejected alternatives, and scope boundaries.
- Flag if `plan.md` re-introduces a rejected alternative or violates an accepted ADR constraint without an explicit override/waiver.
- Severity: **Critical** if direct contradiction to an accepted ADR; **Required** if planned approach deviates without an explicit ADR waiver in Architecture decisions.

---

#### Pass G — Client & product fidelity (`spec-review`)

**Goal:** verify `task.md` + `plan.md` serve user intent as the client experiences the product, not merely literal mechanics.

- **Literal vs intent gap:** flag rows where planned behavior satisfies the AC phrasing to the letter while missing the stated problem in `## Goal & Value` (**Required**).
- **Deleted or renumbered IDs:** flag any gap in `UC-1..N` or `AC-1..N` numbering or any `[wont]` / `[retired]` row still wired into `plan.md` Traceability (**Required**).
- **Missing vs Zero display:** flag user-facing counters, totals, or metrics that lack an explicit empty/unavailable state when inputs are missing (showing `0`, `NaN`, or blank instead of a labeled fallback) (**Required**).
- **Internal jargon / ID leak:** flag user-facing copy, alerts, or error messages in `task.md` or `plan.md` that expose raw database IDs, field names, stack traces, or internal codes (**Required**).

---

### Step 3 — Output report

Produce the Analyze Report directly in the response. **Do not write any files.** Format: `references/analyze-report-template.md`.

## Severity taxonomy

| Severity | Meaning | Action required |
| ---------- | --------- | ----------------- |
| **Critical** | Implementation will fail or produce unverifiable results | Must resolve before `devflow.implement` |
| **Required** | Coverage or quality gap exists; plan is otherwise valid | Resolve before `devflow.implement`; document waiver in `plan.md` Open questions if explicitly skipped |
| **Nit** | Minor consistency or clarity issue | Optional; fix during `devflow.beautify` or ignore |

Blockers = Critical + Required findings.

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Waiving Critical findings without documentation | Document in `plan.md` Open questions |
| Fixing findings in `plan.md` only | Check if root is in `task.md` first |

Full catalog — read when unsure, or before retrying after a failed contract: `references/anti-patterns.md`.

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md` |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md` |
| Reads (conditional) | `docs/adr/` (if present — active ADRs for Pass F check); `references/anti-patterns.md` (when unsure / retry) |
| Reads | `references/analyze-report-template.md` |
| Writes | **Nothing** — strictly read-only |
| Precedes | `devflow.implement` |
| Follows | `devflow.plan` (Status: ready) |
| Related skills | `devflow-plan` (produces artifacts analyzed here); `devflow-clarify` (resolves `[NEEDS CLARIFICATION: ...]` markers) |
