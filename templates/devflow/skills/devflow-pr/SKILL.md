---
name: devflow-pr
description: Commits all changes, pushes the current DevFlow feature branch, and opens a pull request toward main. Use at the final step of the DevFlow pipeline or when the user asks to run devflow.pr.
disable-model-invocation: true
model: haiku
effort: low
---

# Skill: devflow.pr

## Purpose

Commit all changes, push feature branch, open PR to `main`. Final DevFlow step.

---

## Step 0 - Resolve adapter

Read `@devflow/config.md` and `@devflow/adapters/<adapter>/ADAPTER.md`. Use the **PR** section for pre-push verification commands, expected success output, and checklist items that must appear in the PR body.

---

## When NOT to Use

- Any unit or integration test is still failing — fix or document the failure before opening the PR
- The adapter’s analyze/typecheck command reports warnings or errors — resolve them first
- The branch has not been rebased on an up-to-date `main` — rebase before pushing to avoid merge conflicts in the PR
- The PR checklist items are not verifiable — do not open a PR with unresolved checklist items

## Input

- Current feature branch `feat|fix|chore|doc|perf/[NNN]-[feature-name]`
- `devflow/features/[NNN]_[feature-name]/task.md`
- `devflow/features/[NNN]_[feature-name]/plan.md`

---

## Step 1 - Determine commit type

Select type by feature nature:

| Type | When to use |
| --- | --- |
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `chore` | Tooling, dependencies, configuration |
| `docs` | Documentation only |
| `perf` | Performance improvement |

---

## Step 2 - Commit

Delete the feature checkpoint and any leftover handoff first — pipeline complete, session context never committed (`@devflow/references/state-machine.md` → **Checkpoint file**, **Handoff file**). Then stage and commit all changes in a single commit:

```bash
rm -f devflow/features/[NNN]_[feature-name]/.checkpoint.json devflow/features/[NNN]_[feature-name]/handoff.md
git add .
git commit -m "[type]: [short description of the feature]"
```

Rules:

- Message is lowercase, imperative mood, max 72 characters
- No period at the end
- Examples:
  - `feat: add pet profile creation wizard`
  - `fix: resolve auth redirect loop on cold start`
  - `chore: add envied and build runner configuration`

---

## Step 3 - Pre-push verification

Run **every command** in `ADAPTER.md` → **PR** (usually analyze/typecheck, then project-wide tests). Confirm expected success output before push. Do NOT proceed if any command reports issues.

If either command fails, stop and fix the issue before continuing to Step 4.

## Step 4 - Push branch

```bash
git push origin [type]/[NNN]-[feature-name]
```

Where `[type]` is the same prefix used when the branch was created in `devflow.implement` (`feat`, `fix`, `chore`, `perf`, or `doc`).

---

## Step 5 - Open pull request

Use `gh` CLI to open the PR toward `main`:

```bash
gh pr create \
  --base main \
  --title "[type]: [Feature Name]" \
  --body "[PR description - see format below]"
```

### PR title format

```text
[type]: [Feature Name]
```

Examples:

- `feat: Pet Profile Creation Wizard`
- `fix: Auth Redirect Loop on Cold Start`

### PR description format

```markdown
## Summary
[2-4 sentences describing what the feature does, why it was built,
and how it fits into the product.]

## Implementation
[Brief description of the technical approach:
layers touched, key abstractions, notable patterns used.]

## Testing
[How the feature was tested — mirror what `ADAPTER.md` requires:
- Unit tests: what was covered
- Integration / e2e: which flows and targets
- Analyze/typecheck and format: outcome]

## Checklist
[Use the checklist bullets from `ADAPTER.md` → **PR**; add repo-wide items below if not already covered]
- [ ] No hardcoded TODO or placeholder comments
- [ ] `registry.md` updated if new patterns were introduced
```

---

## Step 6 - Notify user

After successful `gh pr create`: set `plan.md` `**Status:** pr-opened` and `task.md` `**Status:** done`; refresh `.devflow-state.json` per `@devflow/references/state-machine.md` → **State update snippet**.

```text
✅ Pull request opened: [type]/[NNN]-[feature-name] -> main

Title: [PR title]
Link: [PR URL returned by gh CLI]

DevFlow pipeline complete for TASK-[NNN].
```

---

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Opening PR with failing tests | Fix or document failures with root cause first |
| Ticking checklist without running commands | Every item must reflect actual command output |
| Skipping `registry.md` update for new patterns | Undocumented patterns → inconsistency |
| `git add .` without reviewing staged files | Run `git status` + `git diff --cached` first |
| Using `fix` for all commit types | `feat` new behavior, `fix` bugs, `chore` tooling |
| PR body without task reference | Include `Closes TASK-NNN` |
| Force-pushing an open PR | Creates follow-up commit instead |
| Skipping `devflow.ship` | Ship gate prevents broken code reaching main |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md`, `@devflow/config.md`, `@devflow/adapters/<adapter>/ADAPTER.md` |
| Runs | `git add .` · `git commit` · `git push` · `gh pr create` |
| Deletes | `devflow/features/[NNN]_[feature-name]/.checkpoint.json`, `devflow/features/[NNN]_[feature-name]/handoff.md` (before staging) |
| Writes | `plan.md` `**Status:** pr-opened`, `task.md` `**Status:** done` |
| Next step | - (end of pipeline) |
