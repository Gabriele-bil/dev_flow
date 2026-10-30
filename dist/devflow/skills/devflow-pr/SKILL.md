---
name: pr
description: Commits all changes, pushes the current DevFlow feature branch, and opens a pull request toward the repo's default branch. Use at the final step of the DevFlow pipeline or when the user asks to run devflow.pr.
argument-hint: "[optional notes for PR body]"
disable-model-invocation: true
effort: low
---

> **Plugin root:** `${CLAUDE_PLUGIN_ROOT}` — in files you read, `@devflow/<references|adapters|skills|agents|scripts>/` and the CLAUDE_PLUGIN_ROOT variable resolve to this directory. `@devflow/config.md` and `devflow/features/` are project files.

# Skill: devflow.pr

**Arguments:** `$ARGUMENTS` — empty → derive PR title/body from `task.md` + `plan.md`.

## Purpose

Commit all changes, push feature branch, open PR to the repo's default branch. Final DevFlow step.

## Core Principles

- **Ethos** — spec-first · traceability · vertical slices · token-lean (caveman-compress); pipeline-wide, defined in the plugin's `ETHOS.md`

## Step 0 - Resolve adapter and base branch

Resolve adapter, adapter root, and app working directory per `${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md` (reads `plan.md`'s `**App:**` field in monorepo mode). Then read `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/ADAPTER.md` (core) plus `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/steps/pr.md`. Use the PR step file for pre-push verification commands, expected success output, and checklist items that must appear in the PR body (monorepo: run verification commands from the resolved app's working directory).

Resolve the base branch instead of assuming `main` — repos also use `master`, `develop`, or `next` as their default:

```bash
BASE_BRANCH="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" base)"   # origin/HEAD, else main|master|develop|next, else main
```

Use `$BASE_BRANCH` in Step 5 and Step 6 below — never a hardcoded `main`.

---

## When NOT to Use

- Any unit or integration test is still failing — fix or document the failure before opening the PR
- The adapter’s analyze/typecheck command reports warnings or errors — resolve them first
- The branch has not been rebased on an up-to-date base branch — rebase before pushing to avoid merge conflicts in the PR
- The PR checklist items are not verifiable — do not open a PR with unresolved checklist items

## Input

- Current feature branch `feat|fix|chore|doc|perf/[NNN]_[feature-name]`
- `devflow/features/[NNN]_[feature-name]/task.md`
- `devflow/features/[NNN]_[feature-name]/plan.md`

---

## Step 1 - Determine commit type

Commit type = branch type prefix set by `devflow.task` (`task.md` `**Branch:**`), so branch, commit and PR title agree. Only mapping: branch `doc/…` → commit type `docs`.

| Branch prefix | Commit type | Meaning |
| --- | --- | --- |
| `feat` | `feat` | New feature or capability |
| `fix` | `fix` | Bug fix |
| `chore` | `chore` | Tooling, dependencies, configuration |
| `doc` | `docs` | Documentation only |
| `perf` | `perf` | Performance improvement |

---

## Step 1b - Ephemeral UI screenshot capture (UI features only)

Identify if the feature includes visual/UI changes:

1. **Detect UI changes:** Inspect `plan.md` for `[ui]` markers or check git diff for frontend/UI paths (`.tsx`, `.jsx`, `.vue`, `.html`, `lib/ui/`, `src/app/`, Flutter widgets).
2. **Headless / non-UI bypass:** If feature touches only backend/data contracts, or environment lacks display/emulator/browser runner (`$DISPLAY` unset and no headless browser/emulator available), skip capture cleanly without failing.
3. **Capture to `/tmp/`:** If UI changes exist and graphical runtime is available, capture visual preview to `/tmp/devflow-ui-preview-[NNN]-[feature-name].png` (via Playwright screenshot, browser agent, or emulator `adb exec-out screencap -p` / `xcrun simctl io booted screenshot`).
4. **Zero-clutter guarantee:** Never save screenshots in repo working directory. Ensure temporary files are isolated to `/tmp/` or gitignored paths.
5. **Manual attach:** `gh` cannot upload images. Captured file path → reported in Step 6 so the user drags it into the PR; never referenced from the PR body.

---

## Step 2 - Commit

Delete session files first — session context is never committed (`${CLAUDE_PLUGIN_ROOT}/references/state-machine.md` → **Checkpoint file**, **Handoff file**). Never delete files this pipeline did not create.

```bash
rm -f devflow/features/[NNN]_[feature-name]/.checkpoint.json devflow/features/[NNN]_[feature-name]/handoff.md
git status --porcelain --untracked-files=all
```

Stage explicitly — never `git add .` / `git add -A`. Expected paths: `plan.md` File List, `devflow/features/[NNN]_[feature-name]/`, plus files the pipeline legitimately touched (`registry.md`, lockfile after a planned dependency change, codegen output of planned files). Stage expected paths only, review, then commit once:

```bash
git add -- <expected-path> [<expected-path> ...]
git diff --cached --stat
git commit -m "[type]: [short description of the feature]"
```

- Unexpected paths (screenshots, `.env*`, build output, editor/OS files, anything outside the list above) → leave unstaged; list them in the Step 6 report.
- Nothing staged → stop, report.

Rules:

- Message is lowercase, imperative mood, max 72 characters
- No period at the end
- Examples:
  - `feat: add pet profile creation wizard`
  - `fix: resolve auth redirect loop on cold start`
  - `chore: add envied and build runner configuration`

---

## Step 3 - Pre-push verification

Run **every command** in the adapter PR step file through the stamp — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/verify-stamp.sh" run lint -- …`, `run analyze -- …`, `run test -- <whole unit suite>`, `run build -- …` (monorepo: `--cwd <app dir>`, `@<app>` suffix). Checks already passed on this exact tree print `fresh … skipped`, so after `devflow.test`/`devflow.ship` usually only `build` runs. Independent checks run in parallel in one shell call — `bash vs run lint -- … & bash vs run analyze -- … & bash vs run build -- … & wait` (vs = the stamp script) — each prints its own result line. Any ✗ → stop, fix, re-run before Step 4. Keep the result lines: they are the evidence for the PR body checklist (Step 5).

## Step 4 - Push branch

```bash
git push origin [type]/[NNN]_[feature-name]
```

Where `[type]/[number-of-task-is-present]_[feature-name]` is the branch set in `devflow.task` (recorded in `task.md` `**Branch:**` and active git branch).

---

## Step 5 - Open pull request

Use `gh` CLI to open the PR toward `$BASE_BRANCH` (resolved in Step 0). Write the description (format below) to a temp file and pass it with `--body-file` — no shell-quoting of multi-line markdown:

```bash
BODY_FILE="$(mktemp "${TMPDIR:-/tmp}/devflow-pr-body.XXXXXX")"
# write PR description to "$BODY_FILE"
gh pr create --base "$BASE_BRANCH" --title "[type]: [Feature Name]" --body-file "$BODY_FILE"
rm -f "$BODY_FILE"
```

Extract decision flags and discrepancies from `plan.md` (`## Decision flags`, `## Deviations`, `## Open questions`) and `task.md` (`## Assumptions & Risks`, `## Notes`). Under `devflow.auto` or whenever autonomous decisions/flags exist, populate `## Autonomous Decisions & Discrepancies` in the PR body so reviewers see every assumption, default, and non-critical exception.

**PR prose fidelity:** Write concrete mechanisms, touched layers, and verified command outputs. Never use AI-slop boosters (`seamless`, `robust`, `comprehensive`, `transformative`, `in conclusion`) or claim checks passed unless they were executed in Step 3.

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

## Autonomous Decisions & Discrepancies
<!-- Included when running under devflow.auto or when decision flags / discrepancies exist in plan.md / task.md -->
[List any discrepancies between idea/spec and implementation, defensible defaults picked, decision flags from plan.md ## Decision flags, assumptions from task.md ## Notes, and non-critical exceptions documented during review.]

## Testing
[What the tests cover (unit, integration/e2e flows and targets), then the Step 3 stamp lines as printed — counts come from them, never from memory. Verification: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" report` → its Verification line.]

## Checklist
[Bullets from the adapter PR step file + repo-wide items below. Every bullet ticked `- [x]` with its evidence: a Step 3 stamp line (lint, analyze, format, test, e2e, build), the Ship Gate report (architecture, conventions, docs, coverage gaps), or a file. Bullet not verifiable or not satisfied → do not open the PR (see When NOT to Use).]
- [x] No TODO or placeholder comments in changed files — [evidence]
- [x] `registry.md` updated for new patterns, or no new patterns — [evidence]

Closes TASK-[NNN]
```

---

## Step 6 - Notify user

After successful `gh pr create`: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set plan pr-opened && bash "${CLAUDE_PLUGIN_ROOT}/scripts/devflow-state.sh" set task done`.

```text
✅ Pull request opened: [type]/[NNN]_[feature-name] -> $BASE_BRANCH

Title: [PR title]
Link: [PR URL returned by gh CLI]
[UI preview: /tmp/devflow-ui-preview-[NNN]-[feature-name].png — drag into the PR to attach]   ← only if captured
[Left unstaged: <paths>]                                                                      ← only if any

DevFlow pipeline complete for TASK-[NNN].
```

---

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Opening PR with failing tests | Fix or document failures with root cause first |
| Ticking checklist without running commands | Every item must reflect actual command output |
| Skipping `registry.md` update for new patterns | Undocumented patterns → inconsistency |
| `git add .` / `git add -A` | Stage expected paths only; review `git diff --cached --stat` |
| Deleting images/files by wildcard to "clean up" | Delete only session files this pipeline created; leave the rest unstaged and report |
| Committing screenshot files to repo working tree | Capture to `/tmp/` only; never stage |
| Embedding a local image path in the PR body | Never renders on GitHub; report path in Step 6 for manual upload |
| Failing PR creation on headless CI | Skip screenshot capture cleanly when no display available |
| Commit type differing from branch prefix | Derive from `**Branch:**` (`doc` → `docs`) |
| PR body without task reference | Include `Closes TASK-NNN` |
| Force-pushing an open PR | Creates follow-up commit instead |
| Skipping `devflow.ship` | Ship gate prevents broken code reaching main |

## I/O Reference

| | |
| --- | --- |
| Reads | `devflow/features/[NNN]_[feature-name]/task.md`, `devflow/features/[NNN]_[feature-name]/plan.md`, `${CLAUDE_PLUGIN_ROOT}/references/adapter-resolution.md`, `${CLAUDE_PLUGIN_ROOT}/adapters/<adapter>/ADAPTER.md` (core) + `steps/pr.md` |
| Runs | `git add -- <expected paths>` · `git commit` · `git push` · `gh pr create --body-file` |
| Deletes | `devflow/features/[NNN]_[feature-name]/.checkpoint.json`, `devflow/features/[NNN]_[feature-name]/handoff.md`, PR body temp file |
| Writes | `plan.md` `**Status:** pr-opened`, `task.md` `**Status:** done` |
| Next step | - (end of pipeline) |
