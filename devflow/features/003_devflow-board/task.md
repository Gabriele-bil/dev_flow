# Task - Static Read-Only Auto-Updating DevFlow Project Board & Command Timing Telemetry

**ID:** TASK-003
**Date:** 2026-10-26
**Status:** done
**Branch:** feat/003_devflow-board
**ADRs:** none
**Blockers:** none
**Unlocks:** none

---

## Goal & Value

- **Problem:** Developers and project leads managing multi-task roadmaps in DevFlow lack a single visual overview of task statuses across pipeline stages, inter-task dependencies (`Blockers`/`Unlocks`), Markdown specification/plan documents, and real execution durations or lead times per pipeline command (`task`, `clarify`, `plan`, `analyze`, `implement`, `test`, `ship`, `pr`, `hotfix`).
- **Objective:** Deliver a deterministic, portable, strictly read-only HTML board command (`/devflow.board`) and core skill (`devflow-board`) backed by automatic hook-driven synchronization and per-command timing telemetry so any consumer project renders an identical, live-synced Kanban, Dependency DAG, Command Timeline, and Markdown inspection dashboard at `devflow/board/index.html` with zero consumer build dependencies.

---

## User Story

**As a** product owner or engineering lead overseeing a software project managed with DevFlow  
**I want to** open a deterministic, read-only visual project board that automatically reflects live Markdown specifications, inter-task dependency graphs, and command execution timings  
**So that** I can track roadmap completion, identify blocked workstreams, inspect feature specifications, and measure pipeline velocity without manual status reporting or risk of mutating repository files from the browser  

---

## Use Cases & Scenarios

### UC-1: Initial Board Generation & Portable Deterministic UI (Write — Initial Setup)
- **Preconditions:** User invokes `/devflow.board` (optionally with `--open`, `--sync`, or `--port <N>`) in a repository containing DevFlow state or feature folders.
- **User Flow:**
  1. System initializes `devflow/board/index.html` from the standardized plugin template (`board-template.html`) and generates the data manifest `devflow/board/board-data.js` (plus `board-data.json` for HTTP fetch mode).
  2. System populates project summary header (project name, active branch, active feature, total tasks, completion percentage, total accumulated development time, and last sync timestamp).
  3. System renders the 5-column read-only Kanban pipeline (`Draft / Clarified`, `Planned / Ready`, `In Progress`, `Implemented / Verified`, `PR Opened / Done`) with task cards showing ID, title, folder slug, branch, status badges, complexity, vertical slice progress (`[x]` / total), blocker/unlock badges, linked ADRs, and development time metrics.
- **Outcome:** `devflow/board/index.html` and `devflow/board/board-data.js` exist with identical UI structure across any consumer project and work both via `file://` protocol and local HTTP server.

### UC-2: Automatic Hook-Driven Synchronization & Live Browser Refresh (Write/Read — Continuous Sync)
- **Preconditions:** `devflow/board/index.html` has already been initialized at least once in the workspace.
- **User Flow:**
  1. When any file under `devflow/features/**` (`task.md`, `plan.md`, `verification.md`), `devflow/plans/project-blueprint.md`, or `.devflow-state.json` changes, or when a pipeline command completes, plugin hooks automatically invoke `board.sh --sync` in the background.
  2. `board.sh --sync` regenerates `devflow/board/board-data.js` (and `board-data.json`) without recreating or altering `devflow/board/index.html`.
  3. When user clicks "Refresh" or enables auto-polling in the browser, the board reloads updated `board-data.js` / fetches live Markdown and telemetry logs, displaying a loading indicator during refresh and disabling duplicate refresh clicks while in flight.
- **Outcome:** Board data stays continuously synchronized with repository state without manual regeneration.

### UC-3: Per-Command Execution Timing & Task Lead Time Telemetry (Write/Read — Telemetry & Timeline)
- **Preconditions:** Developer executes DevFlow commands (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`, `pr`, `hotfix`) on an active feature (`001_<slug>`, `002_<slug>`, etc.).
- **User Flow:**
  1. Lifecycle hooks automatically record command `started_at` and `ended_at` timestamps, compute `duration_sec`, and associate each run with the active feature (`active_feature` in `.devflow-state.json`) and step in `.devflow-timings.jsonl` / `.devflow-metrics.jsonl`.
  2. System computes total accumulated development time per task (`sum(duration_sec)`) and overall task lead time (from initial `task.md` creation timestamp to `done` / `pr-opened` status).
  3. User clicks a task card on the board to inspect the chronological Command Timeline & Metrics breakdown showing each executed command (`/devflow.task`, `/devflow.plan`, `/devflow.implement`, etc.), `started_at`, `ended_at`, `duration_sec`, and estimated tokens/cost USD from `.devflow-metrics.jsonl`.
- **Outcome:** Every task displays accurate per-command timing history, accumulated active development duration, and end-to-end lead time.

### UC-4: Dependency Graph (DAG) & Integrated Markdown Drawer Inspection (Read — Deep Inspection)
- **Preconditions:** Board is open in browser with one or more tasks and optional `project-blueprint.md` / ADRs.
- **User Flow:**
  1. User switches to the **Relations / Dependency Graph (DAG)** view to inspect inter-task dependencies (`**Blockers:**` and `**Unlocks:**` from `task.md` and `devflow/plans/project-blueprint.md`), visually distinguishing completed tasks, ready-to-start tasks, blocked tasks, and the critical path.
  2. User opens the **Markdown Viewer Drawer** on any task or global document (`task.md`, `plan.md`, `verification.md`, `project-blueprint.md`, ADRs).
  3. System renders formatted headings, tables, code blocks, Gherkin (`Given/When/Then`) blocks, interactive-looking read-only checklists (`[x]`/`[ ]`), and frontmatter metadata badges.
- **Outcome:** User inspects dependency bottlenecks and full formatted specification artifacts directly inside the static board without mutating any state.

### UC-5: Empty Workspace or Partial Telemetry Fallback (Edge Case)
- **Trigger:** `/devflow.board` runs in a repository with zero tasks in `devflow/features/` or with tasks lacking `plan.md`, `verification.md`, or `.devflow-timings.jsonl` entries.
- **Expected Behavior:** Board initializes cleanly, displays an informative empty-state banner in Kanban and DAG views, shows `0s` / `—` for unrecorded timings, and disables tabs for absent documents (`plan.md` / `verification.md`) with clear empty-state guidance.

### UC-6: Missing Tooling or Port Conflict on Local Server (Error Handling)
- **Trigger:** `jq` is missing when running `board.sh`, or `--port <N>` is already in use when starting the optional local HTTP preview server.
- **Expected Behavior:** Script emits a clear actionable error message (remediation command for `jq` or port override hint), preserves existing board files without corruption, and exits cleanly (non-blocking `exit 0` when invoked via `--sync --quiet` from hooks).

---

## Acceptance Criteria

- [x] **AC-1 (UC-1) — Deterministic Read-Only Board Initialization:** GIVEN a project using DevFlow WHEN `/devflow.board` executes THEN system creates `devflow/board/index.html` from the canonical `templates/devflow/skills/devflow-board/assets/board-template.html` and generates `devflow/board/board-data.js` containing project summary, 5-column Kanban state, and strictly read-only UI controls (zero state mutation, drag-and-drop, or file writes from browser)
- [x] **AC-2 (UC-2) — Automatic Hook Sync Without Structure Recreation:** GIVEN `devflow/board/index.html` already exists WHEN a file in `devflow/features/**` or `.devflow-state.json` is written or a pipeline turn completes THEN plugin hooks run `board.sh --sync` to update `devflow/board/board-data.js` in place without recreating `index.html`
- [x] **AC-3 (UC-2) — Async Refresh & Double-Submit Protection in UI:** GIVEN the board is open in a browser WHEN user triggers manual Refresh or auto-polling THEN the UI displays a loading indicator, disables the Refresh button while in flight to prevent duplicate requests, and updates all views upon completion or shows a non-destructive retry banner on fetch error
- [x] **AC-4 (UC-3) — Per-Command Timing & Lead Time Telemetry:** GIVEN DevFlow commands (`task`, `clarify`, `plan`, `analyze`, `implement`, `beautify`, `test`, `ship`, `pr`, `hotfix`) run against an active feature WHEN hooks record command execution THEN `.devflow-timings.jsonl` and `board-data.js` capture `started_at`, `ended_at`, `duration_sec`, active feature association, accumulated task development duration, and task lead time (from `task.md` creation to `done` / `pr-opened`)
- [x] **AC-5 (UC-3, UC-4) — DAG Critical Path, Command Timeline & Markdown Viewer:** GIVEN tasks with `Blockers`/`Unlocks`, telemetry logs, and Markdown artifacts WHEN user inspects the board THEN the DAG view highlights blocked/ready/completed tasks and critical path, the task modal displays the chronological command timeline with durations and token/cost estimates, and the Markdown drawer renders formatted `task.md`, `plan.md`, `verification.md`, `project-blueprint.md`, and ADRs including Gherkin blocks and `[x]/[ ]` checklists
- [x] **AC-6 (UC-5, UC-6) — Graceful Empty State & Hook-Safe Error Handling:** GIVEN an empty `devflow/features/` directory or missing optional artifacts WHEN `board.sh` runs directly or via hook `--sync` THEN the board renders informative empty states for missing tasks/tabs AND hook invocations exit `0` without blocking the agent session

---

## Scope Boundaries

**In scope**

- Slash command `templates/devflow/commands/devflow.board.md` supporting `--open`, `--sync`, `--port <N>`, and `--json`.
- Core skill `templates/devflow/skills/devflow-board/SKILL.md` (<250 lines) and immutable UI template `templates/devflow/skills/devflow-board/assets/board-template.html` (dark/light theme, zero consumer build step, works on `file://` and `http://`).
- Generator/sync script `templates/devflow/scripts/board.sh` parsing `devflow/features/*/task.md`, `plan.md`, `verification.md`, `devflow/plans/project-blueprint.md`, `docs/adr/*.md`, `.devflow-state.json`, `.devflow-metrics.jsonl`, and `.devflow-timings.jsonl`.
- Hook extensions (`templates/devflow/hooks/`) to track command `started_at`, `ended_at`, and `duration_sec` per feature and auto-sync `board-data.js` whenever `devflow/board/index.html` exists.
- Behavioral tests for board generation, sync, and command timing hooks, plus catalog/documentation updates (`agent.yaml`, `devflow-discovery`, `README.md`, `templates/devflow/README.md`, `scripts/build-plugin.sh`).

**Out of scope (Not doing)**

- Interactive editing, drag-and-drop status mutation, or browser-to-disk write APIs (board is strictly static and read-only by requirement).
- Requiring Node/npm/webpack bundlers in the consumer project to build or view the board.

---

## Assumptions & Risks

### Assumptions

- Consumer workspaces have `bash` and `jq` available (standard DevFlow prerequisite); optional local HTTP server uses `python3 -m http.server` or `npx serve` if available, while `file://` works out-of-the-box via `<script src="board-data.js"></script>`.
- Command start timestamp (`started_at`) is captured on the first `PreToolUse` event of a turn/step (or command transition in `.devflow-state.json`), and `ended_at` / `duration_sec` are finalized at `Stop` hook execution (`stop-metrics.sh`) and on step transitions.

### Risks

- Synchronous hook execution could slow down tool calls if `board.sh --sync` is heavy; mitigated by running `board.sh --sync --quiet` only from async hooks (`post-task-create.sh`, `post-edit-accumulate.sh` when touching `devflow/`, and `stop-metrics.sh`) with a fast single-pass `jq`/`awk` parser.
- Opening `index.html` directly via `file://` blocks `fetch()` due to browser CORS policy; mitigated by embedding all parsed metadata, telemetry, and full Markdown contents into `devflow/board/board-data.js` (`window.__DEVFLOW_BOARD_DATA__`) and reloading the script tag dynamically on Refresh, while also supporting `fetch()` when served over HTTP.

---

## Notes

- Autonomous run (`devflow.auto`): all functional and technical requirements were specified in detail in the user prompt.
