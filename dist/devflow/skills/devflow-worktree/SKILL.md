---
name: devflow-worktree
description: Creates, lists, or removes isolated git worktrees for parallel feature development, with automatic dev-server port-offset assignment and overlap detection. Use when the user asks to work on a feature in a separate worktree, run two features in parallel, or run devflow.worktree.
argument-hint: [create|remove|list] [feature-name]
disable-model-invocation: true
model: haiku
effort: low
allowed-tools: "Bash(git worktree*) Bash(git branch*) Bash(git status*) Bash(git rev-parse*)"
---

# Skill: devflow.worktree

## Purpose

Create, list, or remove isolated git worktrees for parallel feature development. Each worktree gets its own checkout, branch, and dev-server port offset — no manual port juggling, no colliding on the same files across parallel sessions.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

---

## When NOT to Use

- Only one feature in flight — a normal branch checkout is enough, worktree adds overhead with no benefit
- Uncommitted changes must move into the new worktree unchanged — worktrees check out refs, not working-tree state; commit or stash first
- Adapter has no dev-server command (e.g. a library with no `dev`/`serve` script) — worktree creation still works, just skip the port-offset step

## Input contract

- [ ] Inside a git repository with at least one commit (`git rev-parse --git-dir` succeeds)
- [ ] `create`: feature name given or resolvable from the current `devflow/features/[NNN]_[feature-name]/` directory
- [ ] `remove`: target worktree is listed in `.devflow-worktrees.json`
- [ ] `create`: no uncommitted changes on the branch being worktree'd from (`git status --porcelain` empty) — or user explicitly accepts branching from current `HEAD` only

Any item fails → stop, report which check failed.

---

## Workflow

### Step 1 - Parse arguments

Parse `$ARGUMENTS` as `[create|remove|list] [feature-name]`. Default subcommand: `create`. `feature-name` defaults to the current feature under `devflow/features/[NNN]_[feature-name]/` when omitted.

### Step 2 - List (early exit)

`list` subcommand: read `.devflow-worktrees.json` (empty/missing → "no active worktrees"). Print a table of `path | branch | feature | port offset | created`. Stop here.

### Step 3 - Remove (early exit)

`remove` subcommand: look up `feature-name` in `.devflow-worktrees.json`.

- Not found → stop, report.
- Found → confirm with user (worktree removal discards its checkout if it has uncommitted work), then:

```bash
git worktree remove "$WORKTREE_PATH" --force
```

Remove the matching entry from `.devflow-worktrees.json`. Report success.

### Step 4 - Overlap detection (create path)

Read `.devflow-worktrees.json` (create with `{"worktrees":[]}` if missing). Reject if:

- An entry already exists for `feature-name` (same feature already has a worktree — route user to it instead of creating a duplicate)
- The target branch (`[type]/[NNN]-[feature-name]`, same convention as `devflow.implement` Step 3) already has a worktree checked out elsewhere (`git worktree list --porcelain | grep "$BRANCH"`)

### Step 5 - Assign port offset

Compute the next free offset in steps of 10, skipping any offset already taken in `.devflow-worktrees.json`:

```bash
OFFSET=0
while jq -e --argjson o "$OFFSET" '.worktrees[] | select(.port_offset == $o)' .devflow-worktrees.json >/dev/null 2>&1; do
  OFFSET=$((OFFSET + 10))
done
```

Resolve the adapter's base dev port (read `@devflow/adapters/<adapter>/ADAPTER.md`; fall back to this table when the adapter doc doesn't state one):

| Adapter | Base port |
| --- | --- |
| nextjs | 3000 |
| angular | 4200 |
| nestjs | 3000 |
| flutter (web target) | 8080 |
| common / no dev server | skip offset step |

`ASSIGNED_PORT = BASE_PORT + OFFSET`.

### Step 6 - Create worktree

```bash
git worktree add "../$(basename "$(git rev-parse --show-toplevel)")-worktrees/[feature-name]" -b "[type]/[NNN]-[feature-name]"
```

Path convention: sibling directory `<repo-name>-worktrees/<feature-name>`, keeps worktrees out of the main tree without polluting `.gitignore`.

### Step 7 - Record and notify

Append to `.devflow-worktrees.json`:

```json
{
  "feature": "[NNN]_[feature-name]",
  "branch": "[type]/[NNN]-[feature-name]",
  "path": "../[repo-name]-worktrees/[feature-name]",
  "port_offset": 0,
  "assigned_port": 3000,
  "created": "[ISO 8601 timestamp]"
}
```

```text
✅ Worktree created: ../[repo-name]-worktrees/[feature-name]
Branch: [type]/[NNN]-[feature-name]
Dev-server port: [ASSIGNED_PORT] (base [BASE_PORT] + offset [OFFSET])

cd ../[repo-name]-worktrees/[feature-name]
[adapter dev command] --port [ASSIGNED_PORT]   # or PORT=[ASSIGNED_PORT] for adapters using env var
```

---

## Common Rationalizations

| Thought | Reality |
| --- | --- |
| "Only one worktree active, skip offset math" | Next worktree created later still needs a free slot — always write the offset, even at 0 |
| "User didn't ask for port isolation, just a worktree" | Two worktrees on the default port collide the moment both dev servers run — assign offset unconditionally when the adapter has a dev server |
| "Feature name matches an existing worktree, just reuse it silently" | Silent reuse hides that work is already in progress there — always report the existing worktree and let the user decide |
| "Removing a worktree with uncommitted changes is fine, `--force` handles it" | `--force` discards that work — confirm with the user first |

## Anti-Patterns

| Anti-Pattern | Fix |
| --- | --- |
| Creating a worktree without checking `.devflow-worktrees.json` for overlap | Step 4 overlap detection is mandatory, not optional |
| Hardcoding port 3000 regardless of adapter | Resolve adapter base port from the table, then add the offset |
| Leaving a stale entry in `.devflow-worktrees.json` after manual `git worktree remove` | `remove` subcommand must update both git and the state file together |
| Branching a worktree from a dirty working tree without asking | Input contract requires clean status or explicit user override |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-worktrees.json`, `@devflow/adapters/<adapter>/ADAPTER.md` (base dev port) |
| Runs | `git worktree add` · `git worktree remove` · `git worktree list` · `git branch` |
| Writes | `.devflow-worktrees.json` (add/remove entry) |
| Next step | `devflow.implement` inside the new worktree (separate Claude Code session) |
| Related | `devflow-pr` (base-branch resolution applies the same in a worktree) |
