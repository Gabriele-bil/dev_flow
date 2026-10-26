# Multi-Phase Interview Protocol (`devflow.init`)

Used by `devflow.init` Step 1 — structured elicitation protocol to capture product scope, workspace topology, stack choices, scaffolding mode, and engineering conventions before touching the filesystem.

---

## Elicitation Rules

1. **One question at a time:** Use `AskQuestion` / `ask_question` sequentially. Never batch multiple unrelated questions in a single prompt.
2. **Bounded options with recommendation first:** Offer 2–4 distinct options per question. Prefix the first option with `(Recommended)` followed by a 1-sentence technical rationale grounded in the user's brief.
3. **Adaptive skipping:** If `$ARGUMENTS` or an attached brief already specifies an answer unambiguously (e.g., "Build a Next.js + NestJS Nx monorepo for a clinic booking SaaS"), confirm the extracted parameters in a compact summary and ask only the remaining unresolved questions.
4. **Incremental persistence:** After completing Phase A, Phase B, and Phase C, persist collected answers into `<project-root>/.devflow-init-answers.tmp` (deleted at Step 5 completion and ignored by `.gitignore`) so an interrupted session can resume without re-asking completed phases.

---

## Pre-Flight Questions (Step 0)

### Q0.1 — Target Directory
- **Question:** Where should the project be initialized?
- **Options:**
  - `(Recommended) Create new folder ./<project-slug>/` — isolates the new git repository and workspace cleanly from parent files
  - `Initialize in current working directory (.)` — use when already inside the dedicated empty repository folder

### Q0.2 — Technology File Scaffolding Mode
- **Question:** Should `devflow.init` scaffold live technology project files and install stack packages in addition to DevFlow specs?
- **Options:**
  - `(Recommended) Full Bootstrap (Tech Stack + DevFlow Context + All Tasks)` — runs `@latest` stack CLI generators (Nx, Angular, Next.js, Flutter, NestJS), creates architectural layer folders/barrels, and installs adapter dependencies
  - `DevFlow Specs & Context Only` — creates `AGENTS.md`, `REGISTRY.md`, `constitution.md`, `docs/product.md`, `ADR-001`, `project-blueprint.md`, and all `task.md` files without running stack CLI generators

---

## Phase A — Product & Scope Discovery

Goal: extract complete functional inventory and actors to drive `docs/product.md` and `001..NNN` task decomposition.

### QA.1 — Project Identity & Core Domain
- Collect or confirm `project-name` (`kebab-case` slug, e.g. `acme-commerce`), `product-domain` (1-2 sentences), and `primary-outcome` (measurable user/business value).

### QA.2 — Target Personas & External Actors
- **Question:** Who are the primary user personas and external actors interacting with the system?
- **Rule:** Must be real human roles (e.g., `Customer`, `Store Admin`, `Dispatcher`) or external systems (`Stripe Webhook`, `OAuth Provider`) — never technical roles (`Frontend Developer`, `Database`).
- Offer 2–4 domain-tailored persona sets via `AskQuestion` based on the project brief.

### QA.3 — Feature Inventory (Core + Secondary + Admin/Ops Flows)
- Present a proposed list of 4–10 vertical product features inferred from the brief and ask the user to confirm, add, or trim features.
- Ensure coverage of:
  1. Foundation / authentication / tenant or user onboarding
  2. Primary read/discovery flows (lists, dashboards, search, detail views)
  3. Primary write/mutation flows (creation, booking, checkout, state transitions)
  4. Secondary management, notifications, or settings flows

### QA.4 — Async, Offline & Edge Expectations
- **Question:** What are the primary UX, async, and resilience expectations across user flows?
- **Options:**
  - `(Recommended) Standard Web/Mobile Async` — skeleton loading states, disabled submit controls during in-flight mutations, inline retry on error, and explicit empty-state fallbacks
  - `Optimistic UI + Real-time Streams` — instant local state updates with rollback on failure plus live WebSocket/Supabase/SSE subscriptions
  - `Offline-First + Background Sync` — local cache persistence with queued mutation replay when connectivity returns

---

## Phase B — Architecture, Workspace Topology & Technology Stack

Goal: resolve single-app vs monorepo/Nx topology, stack adapters per app, and the 6 architectural discovery axes (`@devflow/skills/devflow-discover/references/discovery-axes.md`).

### QB.1 — Workspace Topology
- **Question:** What workspace structure fits this project?
- **Options:**
  - `(Recommended when 1 deployable) Single-App Repository` — single application at repository root with direct adapter commands
  - `(Recommended when web + API or multi-client) Nx Integrated/Package-Based Monorepo` — `nx.json` workspace orchestrating multiple apps (`apps/<name>/`) and shared libraries (`libs/` or `packages/`) with task caching and dependency graph boundaries
  - `Standard Multi-App Monorepo (pnpm workspaces / multi-folder)` — explicit `apps/<name>/` directories registered in `@devflow/config.md` without Nx orchestration

### QB.2 — Technology Stack Selection (Asked once for single-app; once per declared app in Monorepo/Nx)
- **Question:** Which technology stack adapter should power `<app-name>`?
- **Options:**
  - `Next.js (nextjs)` — App Router, React Server Components, Server Actions, Zustand, Tailwind CSS + shadcn/ui, Jest + RTL + Playwright
  - `Angular (angular)` — Standalone components, Signals + NgRx Signal Store, Tailwind CSS, Transloco, Vitest + Playwright
  - `Flutter (flutter)` — Flutter 3+, Riverpod + Hooks, Freezed/json_serializable, Easy Localization, Supabase/REST, widget + integration_test/Maestro
  - `NestJS (nestjs)` — Modular DI architecture, TypeORM/PostgreSQL, class-validator + Swagger OpenAPI, Passport JWT, Jest + Supertest

*(Note: In Monorepo/Nx mode, loop to collect each app's `kebab-case` name, relative path e.g. `apps/web/`, `apps/api/`, `apps/mobile/`, and adapter. Require ≥2 apps for monorepo mode.)*

### QB.3 — Data Persistence, Auth & Infrastructure (6 Discovery Axes)
- **Question:** Which backend data store, authentication mechanism, and observability tools will the project use?
- **Options:**
  - `(Recommended for Flutter / rapid full-stack) Supabase (PostgreSQL + Supabase Auth + RLS + Storage)` — activates `supabase` conditional MCP
  - `(Recommended for NestJS / custom backend) PostgreSQL + TypeORM/Prisma + JWT/OAuth` — activates read-only `postgres` conditional MCP
  - `External REST/GraphQL API only (Stateless Client)` — no database MCP added
- **Follow-up (Observability):** Ask whether Sentry error monitoring (`sentry` MCP) is used (`Yes` / `No (Recommended for initial MVP)`).

---

## Phase C — Engineering Conventions, Quality Gates & Run Mode Defaults

Goal: lock in `constitution.md` rules, `REGISTRY.md` baseline patterns, test thresholds, and optional MCP client output.

### QC.1 — Architectural Layering & Import Discipline
- **Question:** Confirm architectural layering and import boundary convention for the selected stack(s):
- **Options:**
  - `(Recommended) Adapter Standard Clean Layering` — uses DevFlow adapter defaults (`domain → data → riverpod → ui` for Flutter; `core → shared → pages` for Angular; `app → components → lib → actions` for Next.js; `modules → controllers → services → entities/repositories` for NestJS) with strict barrel exports (`index.ts` / `index.dart` / `public-api.ts`)
  - `Custom Layer Order` — user specifies custom directory names and dependency flow

### QC.2 — Verification & Test Coverage Threshold
- **Question:** What automated test and verification threshold should `devflow.test` and `devflow.ship` enforce?
- **Options:**
  - `(Recommended) Standard Gate (80% unit coverage + per-AC runtime/E2E verification)` — happy path + ≥1 error path per public surface
  - `Strict Thorough Gate (90% coverage + mandatory Playwright/Maestro E2E + 5-agent ship fan-out)` — recommended for fintech, healthcare, or multi-tenant auth systems
  - `Quick MVP Gate (70% coverage + core AC verification)` — fast iteration for internal prototypes

### QC.3 — MCP Client Configuration (Asked if `--mcp` passed or user opts in)
- **Question:** Which AI coding host should receive generated MCP configuration?
- **Options:**
  - `(Recommended) All detected / Project-local (.mcp.json for Claude Code + Cursor + Antigravity snippet)`
  - `Claude Code (.mcp.json)`
  - `Antigravity (~/.gemini/config/mcp_config.json snippet)`
  - `Skip MCP config generation`
