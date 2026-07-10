---
name: devflow-analyze
description: Read-only check: task.md+plan.md+constitution.md consistency. Flags traceability gaps, untestable ACs, terminology drift, layer violations. Use when user runs devflow.analyze — after devflow.plan (ready), before devflow.implement.
model: haiku
effort: low
---

# Skill: devflow.analyze

## Purpose

Read-only cross-artifact consistency check. Verify `task.md` and `plan.md` are internally consistent and constitution-compliant before implementation begins. Run between `devflow.plan` (Status: ready) and `devflow.implement`.

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

1. `devflow/features/[NNN]_[feature-name]/task.md` — extract: subtask list, acceptance criteria list
2. `devflow/features/[NNN]_[feature-name]/plan.md` — extract: Traceability table (subtask → AC → file(s)), File List (paths + status)
3. `constitution.md` — extract: layer ordering rules and naming conventions

If no path is provided, resolve the highest `NNN_` prefix under `devflow/features/`.

### Step 2 — Run 5 detection passes

Run all passes independently and collect findings. Do not stop after the first failing pass — produce a complete report.

---

#### Pass A — Traceability completeness

**Goal:** every `task.md` subtask has at least one row in the Traceability table with a non-empty file path.

For each subtask in `task.md`:

- Find corresponding rows in `plan.md` Traceability table (match by subtask description).
- No row found → **Critical**: subtask not covered in Traceability.
- Row found but file path is empty or `—` → **Critical**: subtask row has no file mapping.

---

#### Pass B — Acceptance criteria testability

**Goal:** every AC is observable and falsifiable.

For each acceptance criterion in `task.md`:

- Flag if it uses untestable language: "works correctly", "looks good", "behaves as expected", "is user-friendly", "performs well", "is fast", "is clean", "is easy to use".
- Flag if it describes internal implementation state rather than externally observable behavior (e.g. "the class exposes a method…", "the provider is initialized…").
- Severity: **Required** — untestable AC blocks `devflow.test` from writing meaningful assertions.

---

#### Pass C — Terminology consistency

**Goal:** same concept uses the same term in both `task.md` and `plan.md`.

Build a term inventory from both documents. For each conceptual entity (feature name, actor, module, entity, field name), check whether multiple synonyms appear across the two documents.

Flag pairs such as "user profile" / "profile page" / "account page" when they appear to refer to the same thing.

- Severity: **Nit** for minor style divergence; **Required** when divergence crosses a domain boundary (e.g. the same database entity is named differently in Summary vs Architecture decisions).

---

#### Pass D — Constitution alignment

**Goal:** each file path in the File List follows the layer rules in `constitution.md`.

For each entry in `plan.md` File List:

- Extract the directory segment of the path.
- Check it against the layer hierarchy and naming conventions declared in `constitution.md`.
- Flag paths that place a file in a layer that violates declared ordering or naming conventions.
- Severity: **Critical** — layer violations will be flagged by `devflow.beautify` and may cause compile or lint failures.

---

#### Pass E — Coverage balance

**Goal:** no AC maps to 0 files; no file in File List has 0 Traceability rows.

- For each AC in `task.md`: count files linked to it in Traceability. If 0 → **Required**: AC has no implementation mapping.
- For each file in File List: count Traceability rows that reference it. If 0 → **Required**: file is orphaned — not traced to any subtask or AC.

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
| "Traceability close enough" | Untraceable subtasks → silent bugs in `devflow.test` |
| Vague acceptance criteria | `devflow.test` writes from ACs; vague ACs → untestable |
| Skipping analyze ("plan looks fine") | 5-pass structural check; one read catches silent gaps |
| Running analyze mid-implementation | Run before `devflow.implement`; post-impl use `devflow.beautify` |
| Waiving Critical findings without documentation | Document in `plan.md` Open questions |
| Fixing findings in `plan.md` only | Check if root is in `task.md` first |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md` |
| Reads | `devflow/features/[NNN]_[feature-name]/plan.md` |
| Reads | `constitution.md` |
| Reads | `references/analyze-report-template.md` |
| Writes | **Nothing** — strictly read-only |
| Precedes | `devflow.implement` |
| Follows | `devflow.plan` (Status: ready) |
| Related skills | `devflow-plan` (produces artifacts analyzed here); `devflow-clarify` (resolves `[NEEDS CLARIFICATION: ...]` markers) |
