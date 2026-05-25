# Context Files Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the three DevFlow context files (`implement.md`, `research.md`, `review.md`) with missing behavioral constraints already authoritative in the skill files, so agents primed by these contexts operate with fewer gaps.

**Architecture:** Each context file is a short (~20-60 line) behavioral primer loaded at the start of a pipeline step. Enrichments add structured sections (imperative bullets, tables) — not prose. Content is sourced from `devflow-implement`, `devflow-beautify`, and `devflow-plan` SKILL.md files; context files point to skills, they don't re-explain them.

**Tech Stack:** Markdown only. Validate with `bash templates/devflow/scripts/validate-skills.sh` after; rebuild with `bash scripts/build-plugin.sh`.

---

### Task 1: Enrich `contexts/implement.md`

**Files:**
- Modify: `templates/devflow/contexts/implement.md`

Current file is ~20 lines covering basic mode, behavior, priorities, and tools. Missing: adapter loading decision matrix, Stop-the-Line triggers, reuse pre-check reminder, no-commit rule, and mandatory registry update rule.

- [ ] **Step 1: Read the current file**

```bash
cat templates/devflow/contexts/implement.md
```

Expected: ~20 lines as shown in the design doc.

- [ ] **Step 2: Replace `contexts/implement.md` with the enriched version**

The final file content (replace entirely):

```markdown
# Implement Context

Mode: Active implementation
Focus: Writing code per plan.md, following adapter conventions

## Behavior
- Code first, explain after
- Follow plan.md File List order exactly — do not skip or reorder
- Mark each file [done] in plan.md immediately after writing it
- Run adapter format/analyze commands after each batch
- Stop and report if unresolvable error — never invent product rules
- **Never run `git commit`** during implement — not for save points, WIP, or partial progress; commits happen only in devflow.pr

## Adapter loading
- Read `@devflow/config.md` then `@devflow/adapters/<adapter>/ADAPTER.md` before touching code
- Load technology skills per **Implement: skill load decision matrix** in ADAPTER.md — match file paths, load only what applies; never load all skills preemptively

## Reuse pre-check (before writing any file)
- Check shared folder + `registry.md` before creating any component, widget, or service class
- If an existing element covers ≥70% of the need → reuse or extend; do **not** create a parallel implementation
- If plan skipped a reuse audit and you find a candidate → stop and surface it before implementing

## Stop-the-Line triggers
Stop immediately and surface to user if:
- Plan conflicts with existing code or `registry.md`
- Analyze/typecheck command still fails after 3 retries
- A behavior is unspecified and no codebase precedent exists (ask — never invent product rules)
- A shared component candidate was missed by the plan's reuse audit

## Registry update (mandatory)
After all files are written, before Step 7b:
- Any component/widget/utility written to the shared folder → add to `registry.md` immediately
- Any file missing from `registry.md` is invisible to the next agent — never skip

## Priorities
1. Follow plan.md and adapter ADAPTER.md exactly
2. Reuse patterns from registry.md (run pre-check first)
3. Leave no TODOs or placeholder comments

## Tools to favor
- Read for context before writing (plan.md, registry.md, constitution.md)
- Write/Edit for code changes
- Bash for format, analyze, codegen commands
```

- [ ] **Step 3: Verify the file was written correctly**

```bash
wc -l templates/devflow/contexts/implement.md
```

Expected: ~45–55 lines.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/contexts/implement.md
git commit -m "docs(contexts): enrich implement.md with adapter loading, stop-the-line, reuse, no-commit, and registry rules"
```

---

### Task 2: Enrich `contexts/research.md`

**Files:**
- Modify: `templates/devflow/contexts/research.md`

Current file is ~22 lines covering mode, behavior, and a 4-step planning process. Missing: search-first mandate, ordered codebase exploration pattern, dependency mapping step, and a pre-plan checklist (questions to answer before opening devflow-plan).

- [ ] **Step 1: Read the current file**

```bash
cat templates/devflow/contexts/research.md
```

Expected: ~22 lines as shown in the design doc.

- [ ] **Step 2: Replace `contexts/research.md` with the enriched version**

```markdown
# Research Context

Mode: Exploration and planning
Focus: Understanding before acting — do not write application code

## Behavior
- Read widely before proposing anything
- **Search first:** Grep/Glob before proposing any pattern — never invent from memory; what exists in the codebase overrides training knowledge
- Read constitution.md, registry.md, adapter ADAPTER.md before planning
- Document assumptions explicitly in task.md
- Ask about ambiguities — do not invent product rules
- Use MCP docs tools (context7, sequential-thinking) for API research

## Codebase exploration order
Follow this sequence before proposing anything:
1. `constitution.md` — architecture rules and naming conventions
2. `registry.md` — existing shared components, hooks, utilities
3. `devflow/adapters/<adapter>/ADAPTER.md` — stack-specific rules and section pointers
4. `devflow/features/*/` — existing feature dirs for patterns
5. Relevant source files — targeted reads, not full-folder dumps

## Planning process
1. Read task.md and existing feature directories for patterns
2. Explore relevant source files to understand current architecture
3. Identify which adapter sections apply (DB, UI, forms, i18n, state)
4. Map dependencies: shared component candidates from registry.md, external APIs needing context7 research, adapter technology skills devflow-implement will need to load
5. Propose plan only after understanding full scope and dependencies

## Pre-plan checklist
Answer all of these before opening devflow-plan:
- [ ] What do the task.md acceptance criteria require exactly?
- [ ] Which shared components from registry.md are reuse candidates (≥70% coverage)?
- [ ] Which adapter sections apply — and which technology skills will devflow-implement need?
- [ ] Are there open ambiguities about product rules that need user clarification first?

## Tools to favor
- Read for understanding architecture (constitution.md, registry.md)
- Glob/Grep for finding existing patterns before proposing new ones
- Context7 MCP for current API and framework documentation
```

- [ ] **Step 3: Verify the file was written correctly**

```bash
wc -l templates/devflow/contexts/research.md
```

Expected: ~45–55 lines.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/contexts/research.md
git commit -m "docs(contexts): enrich research.md with search-first mandate, exploration order, dependency mapping, and pre-plan checklist"
```

---

### Task 3: Enrich `contexts/review.md`

**Files:**
- Modify: `templates/devflow/contexts/review.md`

Current file is ~23 lines with 7 review axes and a single-sentence severity mention. Missing: 8th axis (Responsiveness and layout), severity as a proper table, explicit scope constraint section, and stall-out rule formalized.

- [ ] **Step 1: Read the current file**

```bash
cat templates/devflow/contexts/review.md
```

Expected: ~23 lines as shown in the design doc.

- [ ] **Step 2: Replace `contexts/review.md` with the enriched version**

```markdown
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
| *(none)* | Required | Fix before merge / next pipeline step |
| **Nit:** | Minor style preference | Optional |
| **Optional:** / **Consider:** | Suggestion | Worth doing; not required |
| **FYI:** | Context only | No code change required |

## Review axes (devflow.beautify)
1. Correctness (logic errors, edge cases, contract adherence, acceptance criteria)
2. Readability (naming, structure, SOLID, Rule of 500, simplifications)
3. Architecture (adapter layer boundaries, dependency direction, import conventions)
4. Security (input validation, auth, secrets — per security-checklist.md)
5. Performance (unnecessary rebuilds, N+1, large payloads, hot-path recreation)
6. UI consistency (adapter theme rules, design-system tokens, no hardcoded styles)
7. Accessibility (WCAG 2.1 AA, keyboard, screen readers, focus management)
8. Responsiveness and layout (required breakpoints, adaptive branching, no raw viewport literals)

## Stall-out rule
After 3 consecutive proposal rounds with no user approval on **any** item, stop proposing and emit:

```
⚠️ Beautify stalled: [N] proposals pending without approval.
Options: (1) approve all remaining, (2) skip all remaining, (3) continue one by one
```

Wait for user choice before continuing.

## Tools to favor
- Read for understanding code and adapter rules
- Grep for finding patterns across files
```

- [ ] **Step 3: Verify the file was written correctly**

```bash
wc -l templates/devflow/contexts/review.md
```

Expected: ~55–65 lines.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/contexts/review.md
git commit -m "docs(contexts): enrich review.md with 8th axis, severity table, scope constraints, and stall-out rule"
```

---

### Task 4: Rebuild dist and validate

**Files:**
- Run: `bash templates/devflow/scripts/validate-skills.sh`
- Run: `bash scripts/build-plugin.sh`
- Stage: `dist/` changes

- [ ] **Step 1: Validate all SKILL.md files**

```bash
bash templates/devflow/scripts/validate-skills.sh
```

Expected: all SKILL.md files pass validation (no errors about context files — they don't require frontmatter).

- [ ] **Step 2: Rebuild dist/**

```bash
bash scripts/build-plugin.sh
```

Expected: exits 0, `dist/devflow/` updated with new context file content.

- [ ] **Step 3: Verify dist context files were updated**

```bash
diff templates/devflow/contexts/implement.md dist/devflow/contexts/implement.md
diff templates/devflow/contexts/research.md dist/devflow/contexts/research.md
diff templates/devflow/contexts/review.md dist/devflow/contexts/review.md
```

Expected: no diff (dist matches templates).

- [ ] **Step 4: Commit dist changes**

```bash
git add dist/
git commit -m "build: rebuild dist after context file enrichments"
```
