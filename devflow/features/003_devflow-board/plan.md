# Plan - Static Read-Only Auto-Updating DevFlow Project Board & Command Timing Telemetry

**ID:** PLAN-003
**Task:** [task.md](file:///Users/gabrielebilello/Developer/dev_flow/devflow/features/003_devflow-board/task.md)
**ADRs:** none
**Date:** 2026-10-26
**Status:** pr-opened
**Complexity:** 14 (thorough)

---

## Overview

Introduces the `/devflow.board` command, `devflow-board` core skill, deterministic single-page HTML template (`templates/devflow/skills/devflow-board/assets/board-template.html`), and generator/sync script (`templates/devflow/scripts/board.sh`). Extends DevFlow lifecycle hooks (`observe.sh`, `stop-metrics.sh`, `post-task-create.sh`, `post-edit-accumulate.sh`) to track per-command execution timings (`started_at`, `ended_at`, `duration_sec`) and task lead times in `.devflow-timings.jsonl` (associated with `active_feature`), and to automatically run `board.sh --sync --quiet` whenever `devflow/features/**` or `.devflow-state.json` changes after initial board setup.

---

## Architecture decisions

- **ADR alignment:** None / complies with `ETHOS.md` and `CONTRIBUTING.md` (core skill `<250` lines, deterministic shell script in `scripts/board.sh`, static template asset in `skills/devflow-board/assets/board-template.html`, async hook safety).
- **Vertical slicing:** 4 vertical slices:
  - **Slice 1 (Telemetry & Hook Auto-Sync Foundation):** Extends `observe.sh`, `stop-metrics.sh`, `post-task-create.sh`, and `post-edit-accumulate.sh` to track `started_at`, `ended_at`, `duration_sec`, and `active_feature` in `.devflow-timings.jsonl` + `.devflow-metrics.jsonl`, and trigger `board.sh --sync --quiet` when `devflow/board/index.html` exists.
  - **Slice 2 (Deterministic Board Engine & Data Manifest Generator):** Implements `templates/devflow/scripts/board.sh` to parse all `devflow/features/*/task.md`, `plan.md`, `verification.md`, `devflow/plans/project-blueprint.md`, `docs/adr/*.md`, `.devflow-state.json`, `.devflow-metrics.jsonl`, and `.devflow-timings.jsonl`, compute lead time, accumulated duration, Kanban column assignment, and DAG critical path, and write `devflow/board/index.html` + `devflow/board/board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) + `devflow/board/board-data.json`.
  - **Slice 3 (Immutable Read-Only HTML/CSS/JS Board UI, Command & Skill):** Creates `board-template.html` (dark/light theme, Project Summary Header, 5-column Kanban pipeline, DAG Dependency Graph with critical path, per-task Command Timeline & Metrics view, and Integrated Markdown Drawer with Gherkin & checklist rendering), `devflow.board.md`, and `devflow-board/SKILL.md`.
  - **Slice 4 (Tests, Eval Cases, Catalog Registration & Plugin Build):** Adds `test-board.sh`, updates `test-stop-metrics.sh` and `run-hook-tests.sh`, adds `devflow-board.json` eval case, updates `agent.yaml`, `devflow-discovery/SKILL.md`, `README.md`, `templates/devflow/README.md`, `.gitignore`, and `scripts/build-plugin.sh` (`SKILLS_MIN=45`).
- **Dual-protocol data loading (`file://` + `http://`):** Browser security blocks `fetch()` on `file://` URLs. `board.sh` writes `devflow/board/board-data.js` (assigning `window.__DEVFLOW_BOARD_DATA__` with all task metadata, telemetry, and raw Markdown strings) AND `devflow/board/board-data.json`. When opened via `file://`, the UI reads `window.__DEVFLOW_BOARD_DATA__` and implements live Refresh/auto-polling by dynamically injecting a cache-busted `<script src="board-data.js?t=...">` tag. When served via HTTP (`--port <N>`), the UI also supports direct `fetch('board-data.json')` and live Markdown `fetch()` fallback. Trade-off: `board-data.js` embeds full Markdown text of feature docs (~5–50 KB per feature), which is negligible for repo-local boards and guarantees zero-server portability.
- **Strictly static, read-only enforcement:** `board-template.html` contains zero `POST`/`PUT`/`DELETE` calls, zero `localStorage` state overrides for task statuses, zero `draggable="true"` or drop handlers, and renders Markdown `[x]`/`[ ]` checkboxes with `disabled` attributes.
- **Per-command timing attribution:** `observe.sh pre` records `command_started_at` (epoch + ISO-8601) and normalized command name (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`, `pr`, `hotfix`) in `.devflow-state.json` when a new turn/step begins or when a skill/command file is read. At turn completion, `stop-metrics.sh` calculates `duration_sec = ended_epoch - started_epoch`, records an entry in `.devflow-timings.jsonl` with `{ts, command, step, feature, active_feature, session, started_at, ended_at, duration_sec, input_tokens, output_tokens, estimated_cost_usd}`, and resets the turn start marker. Additionally, `board.sh` synthesizes fallback timing entries from `task.md`/`plan.md`/`verification.md` file timestamps and `.devflow-metrics.jsonl` when legacy features predate `.devflow-timings.jsonl`.

---

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `board.sh --sync` in hooks slows down Claude tool execution | High | Run `board.sh --sync --quiet` only inside async hooks (`post-task-create.sh`, `post-edit-accumulate.sh`, `stop-metrics.sh`), gate on `[ -f "$WORKSPACE_ROOT/devflow/board/index.html" ]`, and exit `0` on any error |
| `.devflow-state.json` uses `.active_feature` in `devflow.init`/`devflow.task` and `.feature` in `pre-compact.sh` | High | Resolve `FEATURE=$(jq -r '.active_feature // .feature // empty' "$STATE_FILE")` across `observe.sh`, `stop-metrics.sh`, and `board.sh` so both keys are always honored |
| Browser `file://` CORS blocks `fetch()` during Refresh / auto-polling | Med | Refresh dynamically appends `<script src="board-data.js?ts=Date.now()">` to reload `window.__DEVFLOW_BOARD_DATA__` in `file://` mode, and uses `fetch()` when `location.protocol.startsWith('http')` |
| `SKILL.md` line count >250 or description collision >=50% in `run-evals.sh` | Med | Keep `templates/devflow/skills/devflow-board/SKILL.md` under 180 lines, set `disable-model-invocation: true`, and verify with `validate-skills.sh --strict` and `run-evals.sh` |

---

## Open questions

None. All requirements resolved from user prompt and repo conventions.

---

## Decision flags

- **Dual-protocol (`file://` + `http://`) manifest strategy:** `board.sh` writes both `devflow/board/board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) and `devflow/board/board-data.json`. In `file://` mode, Refresh dynamically reloads `<script src="board-data.js?t=...">`; in `http://` mode, Refresh fetches `board-data.json` and supports live Markdown `.md` fetching with fallback to `board-data.js`.
- **State key compatibility (`.active_feature // .feature`):** Resolved across `observe.sh`, `stop-metrics.sh`, `post-task-create.sh`, and `board.sh` so both `.active_feature` (used by `devflow.init`/`devflow.task`) and `.feature` (used by `pre-compact.sh`) are supported.
- **Ship Gate Iteration 1 fixes applied:** Added error logging + retry banner in `board-template.html` `.catch()`, recorded initial `task` timing event in `post-task-create.sh`, kept `total_dev_sec` independent of `lead_time_sec` when `total_dev_sec == 0` in `board.sh`, ensured `devflow/board/` is added to `.gitignore` by `board.sh`, and added WCAG keyboard support (`tabindex="0"`, `role="button"`, `Enter`/`Space`) to interactive task cards and DAG nodes.

---

## Traceability

| Use Case / Subtask | Acceptance criteria | File(s) |
|---------------------|---------------------|---------|
| UC-1: Initial Board Generation & Portable Deterministic UI | AC-1: GIVEN a project using DevFlow WHEN `/devflow.board` executes THEN system creates `devflow/board/index.html` from `board-template.html` and generates `devflow/board/board-data.js` with project summary, 5-column Kanban, and strictly read-only UI | `templates/devflow/commands/devflow.board.md`, `templates/devflow/skills/devflow-board/SKILL.md`, `templates/devflow/skills/devflow-board/assets/board-template.html`, `templates/devflow/scripts/board.sh` |
| UC-2: Automatic Hook-Driven Synchronization & Live Browser Refresh | AC-2: GIVEN `devflow/board/index.html` exists WHEN a file in `devflow/features/**` or `.devflow-state.json` changes or a turn ends THEN hooks run `board.sh --sync` updating `board-data.js` without recreating `index.html` | `templates/devflow/scripts/board.sh`, `templates/devflow/hooks/post-task-create.sh`, `templates/devflow/hooks/post-edit-accumulate.sh`, `templates/devflow/hooks/stop-metrics.sh` |
| UC-2: Automatic Hook-Driven Synchronization & Live Browser Refresh | AC-3: GIVEN board is open in browser WHEN user triggers Refresh or auto-polling THEN UI displays loading indicator, disables Refresh button while in flight, and updates views or shows retry banner | `templates/devflow/skills/devflow-board/assets/board-template.html` |
| UC-3: Per-Command Execution Timing & Task Lead Time Telemetry | AC-4: GIVEN DevFlow commands run against an active feature WHEN hooks record execution THEN `.devflow-timings.jsonl` and `board-data.js` capture `started_at`, `ended_at`, `duration_sec`, `active_feature`, accumulated duration, and task lead time | `templates/devflow/hooks/observe.sh`, `templates/devflow/hooks/stop-metrics.sh`, `templates/devflow/hooks/post-task-create.sh`, `templates/devflow/scripts/board.sh` |
| UC-4: Dependency Graph (DAG) & Integrated Markdown Drawer Inspection | AC-5: GIVEN tasks with `Blockers`/`Unlocks`, telemetry, and Markdown docs WHEN user inspects board THEN DAG highlights critical path/blocked/ready/completed tasks, timeline modal shows command breakdown + cost, and Markdown drawer renders formatted docs with Gherkin and `[x]/[ ]` checklists | `templates/devflow/skills/devflow-board/assets/board-template.html`, `templates/devflow/scripts/board.sh` |
| UC-5 & UC-6: Empty Workspace & Hook-Safe Error Handling | AC-6: GIVEN empty `devflow/features/` or missing artifacts WHEN `board.sh` runs directly or via `--sync` THEN board renders empty states AND hook invocations exit `0` cleanly | `templates/devflow/scripts/board.sh`, `templates/devflow/skills/devflow-board/assets/board-template.html`, `templates/devflow/scripts/test-board.sh`, `templates/devflow/hooks/tests/test-stop-metrics.sh` |

---

## File List

Ordered by implementation sequence.

**Batch:** M

**Slice 1 — Telemetry & Hook Auto-Sync Foundation** (deps: none) [route: mid]

### 001. `templates/devflow/hooks/observe.sh` - modify [done]
- **Change:** Resolve `FEATURE` from `.active_feature // .feature` in `.devflow-state.json`; track `turn_started_at` (ISO-8601), `turn_started_epoch` (seconds), and inferred `active_command` (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`, `pr`, `hotfix`) in `.devflow-state.json` on `pre` events when not already set for the current turn or when a skill/command file is read.
- **Contract:** Preserves existing `.devflow-observe.jsonl` schema, strategic-compact counter, and retry-loop detection while seeding command start timing for `stop-metrics.sh`.
- **Test:** `bash templates/devflow/scripts/run-hook-tests.sh`.
- **Out of scope:** Changing retry-loop threshold or log rotation limits.

### 002. `templates/devflow/hooks/stop-metrics.sh` - modify [done]
- **Change:** Resolve `FEATURE` from `.active_feature // .feature`, infer normalized `COMMAND` (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`, `pr`, `hotfix`) from `.active_command // .next_step` and transcript/state, compute `started_at`, `ended_at`, and `duration_sec`, append timing entry to `.devflow-timings.jsonl` (and include timing fields in `.devflow-metrics.jsonl`), ensure `.devflow-timings.jsonl` is in `.gitignore`, clear `turn_started_at`/`turn_started_epoch` in `.devflow-state.json`, and trigger `board.sh --sync --quiet` if `devflow/board/index.html` exists.
- **Contract:** Backwards-compatible with `test-stop-metrics.sh` and `metrics.sh`; records `.devflow-timings.jsonl` even when token usage is 0 or transcript is minimal if a command turn occurred, and triggers board sync.
- **Test:** `bash templates/devflow/hooks/tests/test-stop-metrics.sh` and `bash templates/devflow/scripts/test-board.sh`.
- **Out of scope:** Changing LLM $/MTok pricing rates.

### 003. [P] `templates/devflow/hooks/post-task-create.sh` - modify [done]
- **Change:** Preserve/set `active_feature` alongside `next_feature_number` when `devflow/features/NNN_*/task.md` is written, record an initial `task` timing event in `.devflow-timings.jsonl` if none exists for that feature yet, and run `board.sh --sync --quiet` if `devflow/board/index.html` exists.
- **Contract:** Preserves all existing `test-post-task-create.sh` assertions (`next_feature_number` increment and existing field merge).
- **Test:** `bash templates/devflow/hooks/tests/test-post-task-create.sh`.
- **Out of scope:** Modifying non-`task.md` write behavior in `post-task-create.sh`.

### 004. [P] `templates/devflow/hooks/post-edit-accumulate.sh` - modify [done]
- **Change:** When a written/edited file matches `devflow/features/*`, `devflow/plans/*`, `docs/adr/*`, or `.devflow-state.json` and `devflow/board/index.html` exists, invoke `board.sh --sync --quiet` asynchronously.
- **Contract:** Keeps `.devflow-changed-files.tmp` accumulation intact and never blocks tool execution.
- **Test:** `bash templates/devflow/scripts/test-board.sh`.
- **Out of scope:** Changing `stop-format-typecheck.sh`.

**Batch:** L

**Slice 2 — Deterministic Board Engine & Data Manifest Generator** (deps: 1) [route: strong]

### 005. `templates/devflow/scripts/board.sh` - create [done]
- **Change:** Create deterministic board generator and sync CLI supporting `--sync`, `--quiet`, `--open`, `--port <N>`, `--json`, and `--help`:
  - First run (or without `--sync`): copies `templates/devflow/skills/devflow-board/assets/board-template.html` to `devflow/board/index.html` (byte-identical) and generates `devflow/board/board-data.js` + `devflow/board/board-data.json`.
  - `--sync` mode: if `devflow/board/index.html` exists, regenerates only `devflow/board/board-data.js` and `devflow/board/board-data.json` without touching `index.html`.
  - Parses all `devflow/features/[NNN]_*/` directories (`task.md`, `plan.md`, `verification.md`), `devflow/plans/project-blueprint.md`, `docs/adr/*.md`, `.devflow-state.json`, `.devflow-metrics.jsonl`, and `.devflow-timings.jsonl`.
  - Computes per-task Kanban column (`draft_clarified`, `planned_ready`, `in_progress`, `implemented_verified`, `pr_opened_done`), slice progress (`done`/`total` from `### ... [done]`/`[pending]` and `- [x]`/`- [ ]`), `Blockers` (with resolved `is_blocked` boolean checking whether blocker tasks are `done`/`pr-opened`), `Unlocks`, ADR links, per-command timeline breakdown, total development time (`duration_sec`), and task `lead_time_sec` (from `task.md` creation to `done`/`pr-opened`).
  - Computes DAG critical path across inter-task dependencies using topological longest-path analysis.
- **Contract:** Exits `0` on success or when `--sync --quiet` is invoked from hooks; exits `1` on invalid CLI flags or missing required tools in interactive mode.
- **Test:** `bash templates/devflow/scripts/test-board.sh`.
- **Out of scope:** Mutating any file under `devflow/features/`.

**Batch:** L

**Slice 3 — Immutable Read-Only HTML/CSS/JS Board UI, Command & Skill** (deps: 2) [route: strong]

### 006. [ui] `templates/devflow/skills/devflow-board/assets/board-template.html` - create [done]
- **Change:** Create standardized, self-contained, zero-dependency, read-only single-page HTML application featuring:
  1. **Project Header & Summary Bar:** Project name, current git branch, active feature badge (from `.devflow-state.json`), total tasks, completion %, total project development time, last updated timestamp, theme toggle (dark/light), search/filter bar, auto-poll toggle (5s/15s/off), and Refresh button with spinner + disabled in-flight protection.
  2. **Read-Only Kanban Pipeline View:** 5 columns (`Draft / Clarified`, `Planned / Ready`, `In Progress`, `Implemented / Verified`, `PR Opened / Done`). Each card displays `TASK-NNN` ID, title, folder slug, branch (`feat/...`), `task.md` + `plan.md` status badges, Complexity badge, Vertical Slice progress bar (`[x]/total`), `Blockers` (red/locked badge if unresolved, green/unlocked if resolved) + `Unlocks` + ADR badges, and development timing footer (total active dev time, lead time, `started_at` first run, `ended_at` last command).
  3. **Relations / Dependency Graph (DAG) View:** Interactive read-only SVG/layered DAG visualizing `Blockers` → `Unlocks` edges from `task.md` and `project-blueprint.md`, highlighting the Critical Path, Completed tasks, Ready-to-develop tasks, and Blocked tasks. Clicking any node opens its detail & Markdown drawer.
  4. **Task Command Timeline & Telemetry Modal/Tab:** Chronological breakdown of every DevFlow command executed on the selected task (`/devflow.task`, `/devflow.clarify`, `/devflow.plan`, `/devflow.analyze`, `/devflow.implement`, `/devflow.beautify`, `/devflow.test`, `/devflow.ship`, `/devflow.pr`, `/devflow.hotfix`), showing `started_at`, `ended_at`, `duration_sec` (with proportional duration bar), and estimated tokens/cost USD from `.devflow-metrics.jsonl`.
  5. **Integrated Markdown Viewer Drawer:** Slide-over drawer with tabs for task docs (`task.md`, `plan.md`, `verification.md`) and global docs (`project-blueprint.md`, ADRs), rendering headings, tables, fenced code blocks, highlighted Gherkin (`Given`/`When`/`Then`/`And`) blocks, read-only `[x]`/`[ ]` checklists, and frontmatter metadata pills.
- **Contract:** Loads `board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) for `file://` compatibility and supports `fetch('board-data.json')` + direct `.md` fetch when served via HTTP. Strictly read-only (zero mutation endpoints, zero drag-and-drop).
- **Test:** Verified via `test-board.sh` DOM/content assertions and headless syntax validation.
- **Out of scope:** External CDN font/script requirements that fail offline.

### 007. [P] `templates/devflow/commands/devflow.board.md` - create [done]
- **Change:** Create slash command entry point for `/devflow.board` supporting `--open`, `--sync`, `--port <N>`, and `--json`.
- **Contract:** Dispatches `@devflow/skills/devflow-board/SKILL.md` with mandatory execution anchors.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` and `bash templates/devflow/scripts/run-evals.sh`.
- **Out of scope:** Inline shell script logic.

### 008. `templates/devflow/skills/devflow-board/SKILL.md` - create [done]
- **Change:** Create core skill (<250 lines) with YAML frontmatter (`name: devflow-board`, `description`, `argument-hint: "[--open] [--sync] [--port <port>] [--json]"`, `disable-model-invocation: true`), `## Purpose`, `## Core Principles` (exact 4 bullets from `ETHOS.md`), `## When NOT to Use`, `## Input contract`, `## Workflow`, `## Common Rationalizations`, `## Anti-Patterns`, and `## I/O Reference`.
- **Contract:** Invokes `@devflow/scripts/board.sh` and enforces deterministic read-only template usage from `@devflow/skills/devflow-board/assets/board-template.html`.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict` (0 errors, 0 warnings, <250 lines).
- **Out of scope:** Modifying consumer feature files.

**Batch:** M

**Slice 4 — Tests, Eval Cases, Catalog Registration & Plugin Build** (deps: 1, 2, 3) [route: mid]

### 009. [P] `templates/devflow/evals/cases/devflow-board.json` - create [done]
- **Change:** Add 3 positive and 2 negative NL trigger evaluation prompts for `devflow-board`.
- **Contract:** Passes `bash templates/devflow/scripts/run-evals.sh`.
- **Test:** `bash templates/devflow/scripts/run-evals.sh`.
- **Out of scope:** Modifying eval runner logic.

### 010. `templates/devflow/scripts/test-board.sh` - create [done]
- **Change:** Create behavioral test suite testing: (1) empty workspace initialization, (2) multi-task Kanban column classification (`Draft/Clarified`, `Planned/Ready`, `In Progress`, `Implemented/Verified`, `PR Opened/Done`), (3) `Blockers`/`Unlocks` resolution and DAG critical path calculation, (4) command timing telemetry in `.devflow-timings.jsonl` + lead time computation, (5) `--sync` updating `board-data.js` without modifying `index.html` inode/mtime, (6) automatic hook sync via `post-task-create.sh`, `post-edit-accumulate.sh`, and `stop-metrics.sh`.
- **Contract:** Exits `0` when all assertions pass; `1` on any failure.
- **Test:** `bash templates/devflow/scripts/test-board.sh`.
- **Out of scope:** Browser E2E daemon startup during CI unit tests.

### 011. [P] `templates/devflow/hooks/tests/test-stop-metrics.sh` - modify [done]
- **Change:** Add test case verifying `.devflow-timings.jsonl` generation with `started_at`, `ended_at`, `duration_sec`, and `active_feature` resolution, plus auto-sync of `devflow/board/board-data.js` when `devflow/board/index.html` exists.
- **Contract:** All existing `T1..T4` tests and new `T5` timing/board-sync assertions pass.
- **Test:** `bash templates/devflow/hooks/tests/test-stop-metrics.sh`.
- **Out of scope:** Modifying `test-output-filter.sh`.

### 012. [P] `templates/devflow/scripts/run-hook-tests.sh` - modify [done]
- **Change:** Execute `test-board.sh` alongside `test-learning-hooks.sh` and `test-metrics.sh`.
- **Contract:** `bash templates/devflow/scripts/run-hook-tests.sh` runs syntax checks + all hook suites + `test-board.sh`.
- **Test:** `bash templates/devflow/scripts/run-hook-tests.sh`.
- **Out of scope:** Changing existing hook test runners.

### 013. [P] `templates/devflow/skills/devflow-discovery/SKILL.md` - modify [done]
- **Change:** Add `devflow.board` to Quick Intent Mapping table so users asking for visual kanban/board/roadmap/timing view are routed to `devflow.board`.
- **Contract:** Passes `validate-skills.sh --strict`.
- **Test:** `bash templates/devflow/scripts/validate-skills.sh --strict`.
- **Out of scope:** Changing SessionStart hook logic.

### 014. [P] `templates/devflow/agent.yaml` - modify [done]
- **Change:** Register `/devflow.board` under `pipeline.utility` and `devflow-board` (`skills/devflow-board/SKILL.md`) under `skills.core`.
- **Contract:** Passes `run-evals.sh` Check 3 (zero catalog drift).
- **Test:** `bash templates/devflow/scripts/run-evals.sh`.
- **Out of scope:** Modifying adapter skill entries.

### 015. [P] `README.md` - modify [done]
- **Change:** Add `devflow.board` to Commands table and `devflow-board/` to Repository layout skills tree.
- **Contract:** Passes `validate-doc-links.sh`.
- **Test:** `bash templates/devflow/scripts/validate-doc-links.sh`.
- **Out of scope:** Modifying adapter sections.

### 016. [P] `templates/devflow/README.md` - modify [done]
- **Change:** Add `devflow.board` to Commands table in plugin README.
- **Contract:** Passes `validate-doc-links.sh`.
- **Test:** `bash templates/devflow/scripts/validate-doc-links.sh`.
- **Out of scope:** Modifying adapter tables.

### 017. `scripts/build-plugin.sh` - modify [done]
- **Change:** Copy `scripts/board.sh` into `dist/devflow/scripts/board.sh` (via `build-claude.sh` or `build-plugin.sh`), increment `SKILLS_MIN` from `44` to `45`, update `.gitignore` with `.devflow-timings.jsonl` and `devflow/board/`, and run `bash scripts/build-plugin.sh`.
- **Contract:** `dist/devflow/` contains `commands/devflow.board.md`, `skills/devflow-board/SKILL.md`, `skills/devflow-board/assets/board-template.html`, and `scripts/board.sh`; build exits `0` with 45 skills.
- **Test:** `bash scripts/build-plugin.sh`.
- **Out of scope:** Modifying Cursor/Antigravity manifest schemas.

---

## Implementation checkpoints

- **After Slice 1:** Run `bash -n` on all modified hooks and `bash templates/devflow/hooks/tests/test-post-task-create.sh`.
- **After Slice 2:** Run `bash -n templates/devflow/scripts/board.sh` and test `board.sh --json` output structure.
- **After Slice 3:** Run `bash templates/devflow/scripts/validate-skills.sh --strict` to verify `devflow-board/SKILL.md` (<250 lines, 0 warnings, valid references).
- **After Slice 4:** Run all 5 required validation suites: `validate-skills.sh --strict`, `run-evals.sh`, `run-hook-tests.sh`, `build-plugin.sh`, and `validate-doc-links.sh`.

---

## Edge Cases & Error Handling

- **Legacy features without `.devflow-timings.jsonl`:** `board.sh` synthesizes timing entries from `.devflow-metrics.jsonl` (grouped by feature + step) and file creation/modification timestamps (`git log` / `stat` on `task.md`, `plan.md`, `verification.md`) so existing tasks (`001`, `002`) immediately display rich timeline and lead-time metrics.
- **Tasks with `Blockers: none` or multiple comma-separated blockers (`TASK-001, TASK-002`):** Parser normalizes `TASK-NNN` prefixes to `NNN_<slug>` feature IDs, checks whether every blocker has `task.md` Status `done` or `plan.md` Status `pr-opened`, and computes `is_blocked` accurately.
- **Read-only security in Markdown renderer:** Custom Markdown parser in `board-template.html` escapes raw HTML entities (`&`, `<`, `>`) before applying Markdown formatting rules to prevent XSS when rendering untrusted text inside `task.md` or `plan.md`.

---

## Pre-implement checklist

- [x] Constitution Gate passed (Step 0b) — no Critical violations
- [x] Every `task.md` use case / subtask appears in **Traceability** with its acceptance criterion
- [x] Every **File List** entry maps to ≥1 **Traceability** row — no orphan/gold-plated files
- [x] **File list** order respects **Dependency ordering** (and any stated exceptions)
- [x] All **adapter-specific sections** from `ADAPTER.md` are present or correctly omitted per adapter rules
- [x] **Implementation checkpoints** are actionable
- [x] **Open questions** are empty or resolved if **Status** is `ready`
- [x] Existing shared components checked; no duplication of a component already in `shared/`
- [x] New reusable components identified in this plan are listed under their `shared/` path in the **File List**
- [x] `devflow.analyze` run (or explicitly waived) — no Critical findings
- [x] If feature touches persistent entities → `data-model.md` exists and is non-empty (N/A)
- [x] `**Complexity:**` recorded per `references/complexity-scoring.md` — profile floor applied
