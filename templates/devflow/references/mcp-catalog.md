# MCP Catalog & Configuration Guide

Authoritative reference for Model Context Protocol (MCP) servers across DevFlow adapters.

---

## Core Principles

1. **Zero hard runtime dependency (graceful degradation)**: All DevFlow pipeline skills degrade cleanly to native CLI commands (`pnpm test`, `git`, `grep`, `dart analyze`) if an MCP server is unavailable.
2. **Tool budget discipline**: Active MCP servers should remain focused (typically 3–6 per project) to avoid context window bloating and tool selection confusion.
3. **Strict conditional inclusion**: Add infrastructure MCPs (like Supabase, PostgreSQL, Sentry) **ONLY** if the project actually uses them. If an application does not use Supabase, the Supabase MCP is not included. If it does not use PostgreSQL, the PostgreSQL MCP is not included.
4. **Database read-only policy**: Database MCP servers must always be configured with read-only credentials to prevent unauthorized data mutations or unversioned schema changes outside formal migrations.

---

## Catalog by Tier

### 1. Universal Baseline (All Projects)

| Server | Command / URL | Role in DevFlow |
| :--- | :--- | :--- |
| **`context7`** | `https://mcp.context7.com/mcp` | Live, version-specific API docs and delta changes for libraries/frameworks. |
| **`sequential-thinking`** | `npx -y @modelcontextprotocol/server-sequential-thinking` | Step-by-step reasoning for complex refactoring, migration planning, and debugging. |
| **`code-review-graph`** | stdio, registered by `code-review-graph install` — see [code-review-graph setup](#code-review-graph-setup-claude-code--antigravity) | Tree-sitter code graph (Dart, TS/TSX, …) for index-first exploration and blast radius (`token-economy.md`). |

### 2. Stack-Specific Core

| Stack | Server | Command / Transport | Role in DevFlow |
| :--- | :--- | :--- | :--- |
| **Angular** | **`angular-cli`** | `npx -y @angular/cli mcp` | Official Angular conventions (`get_best_practices`), zoneless migrations, local devserver lifecycle. |
| **Flutter** | **`dart`** | `dart mcp-server` (official, Dart SDK ≥ 3.9) | Symbol lookup, package APIs, SDK diagnostics and signatures. |
| **Next.js** | **`next-devtools`** | `npx -y next-devtools-mcp@latest` (connects to `/_next/mcp`) | Live dev errors (`get_errors`), routes (`get_routes`), Server Actions inspection. |
| **NestJS** | **`openapi`** | `npx -y @ivotoby/openapi-mcp-server` with `TOOLS_MODE=dynamic`, `OPENAPI_SPEC_PATH=http://localhost:3000/api-json` | Contract introspection of the app's own Swagger spec: `list-api-endpoints`, `get-api-endpoint-schema` (DTO and validation boundaries); `invoke-api-endpoint` only against the local dev server. |
| **Web UI (Next / Angular)** | **`playwright`** | `npx -y @playwright/mcp@latest` | ARIA tree snapshots in `devflow.beautify` (a11y) and browser execution in `devflow.test` (Level 4 verify). |

### 3. Conditional Infrastructure (Add ONLY when used)

| Server | Condition | Command / Transport | Purpose |
| :--- | :--- | :--- | :--- |
| **`supabase`** | Project uses Supabase (`supabase_flutter`, `@supabase/*`, or Supabase backend) | `https://mcp.supabase.com/mcp?project_ref=<ref>&read_only=true` | Introspect remote schemas, tables, RLS policies during planning and migration verification. |
| **`postgres`** | Project connects directly to PostgreSQL (`pg`, TypeORM/Prisma postgres driver) | `npx -y mcp-postgres-server` or `@microsoft/postgres-mcp` | Read-only live schema check and index verification to prevent migration drifts. *(Note: deprecated `@modelcontextprotocol/server-postgres` is prohibited due to SQLi vulnerabilities)*. |
| **`shadcn`** | Next.js project uses shadcn/ui (`components.json` at app root) | `npx -y shadcn@latest mcp` | Browse/search registry components and install them with the CLI instead of hand-copying source. |
| **`sentry`** | Project uses Sentry for monitoring (`@sentry/*`, `sentry_flutter`) | `https://mcp.sentry.dev/mcp` (Streamable HTTP + OAuth; `/sse` is legacy) | Error triage, issue search, stack trace retrieval during `devflow.backprop`. |

---

## Client Configuration Examples

Same server entries for both clients; only the file differs.

| Client | Project scope | User scope |
| :--- | :--- | :--- |
| Claude Code | `.mcp.json` | `~/.claude.json` (`claude mcp add --scope user`) |
| Antigravity | `.agents/mcp_config.json` | `~/.gemini/antigravity/mcp_config.json` |

```json
{
  "mcpServers": {
    "context7": {
      "serverUrl": "https://mcp.context7.com/mcp"
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    },
    "openapi": {
      "command": "npx",
      "args": ["-y", "@ivotoby/openapi-mcp-server"],
      "env": {
        "API_BASE_URL": "http://localhost:3000",
        "OPENAPI_SPEC_PATH": "http://localhost:3000/api-json",
        "TOOLS_MODE": "dynamic"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "mcp-postgres-server"],
      "env": {
        "DATABASE_URL": "postgresql://readonly_user:secret@localhost:5432/app_db",
        "PG_ALLOW_WRITE": "false"
      }
    }
  }
}
```

Remote servers: Claude Code takes `"type": "http", "url": "<url>"`; Antigravity takes `"serverUrl": "<url>"`. `openapi`: the spec path follows `SwaggerModule.setup('<path>', …)` → `/<path>-json`; with the dev server down, point `OPENAPI_SPEC_PATH` at an exported `openapi.json` instead.

### code-review-graph setup (Claude Code + Antigravity)

One graph per repo (`.code-review-graph/graph.db`, gitignored by `install`); each client only needs its own MCP entry.

```bash
pipx install code-review-graph
code-review-graph install --platform claude-code --no-skills --no-instructions -y   # .mcp.json + git hooks
code-review-graph install --platform antigravity --no-skills --no-instructions -y   # ~/.gemini/antigravity/mcp_config.json
code-review-graph build
```

- `--no-skills` / `--no-instructions`: DevFlow owns routing (`token-economy.md`) and the managed `AGENTS.md`; the bundled review/explore skills would collide with `devflow.ship` and duplicate instructions in `CLAUDE.md` / `AGENTS.md`.
- Keep `--steering` off (adds tokens on every Grep/Read).
- Freshness: the git hooks (`pre-commit`, `post-checkout`, `post-merge`, `post-rewrite`) run `code-review-graph update` and are client-agnostic, so they keep the graph current for Antigravity sessions too. Stale graph mid-session → `code-review-graph update --brief`.
- Tool budget: add `"env": { "CRG_TOOLS": "get_minimal_context_tool,query_graph_tool,semantic_search_nodes_tool,get_impact_radius_tool,get_review_context_tool,detect_changes_tool" }` to each `code-review-graph` entry — six read-only tools instead of 30. `install` leaves hand-edited entries untouched.
- Exclude generated code (`*.g.dart`, `*.freezed.dart`, `dist/`, `.next/`) via `.code-review-graphignore`.

---

## Setup Integration (`devflow.setup`)

During `devflow.setup`:

1. Scans project dependencies (`package.json`, `pubspec.yaml`) and questionnaire answers (DB / backend decisions).
2. Generates the `{{mcp-baseline}}` value in `AGENTS.md` containing only the universal baseline + active stack core + detected infrastructure.
3. If an app does not use Supabase, `supabase` is excluded. If an app does not use PostgreSQL, `postgres` is excluded.
