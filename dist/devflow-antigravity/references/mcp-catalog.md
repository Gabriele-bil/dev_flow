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
| **Code Index (`serena` / LSP)** | `uvx --from git+https://github.com/oraios/serena serena start-mcp-server` | AST/semantic code graph (`token-economy.md`): one-call resolution of callers, callees, symbols. |

### 2. Stack-Specific Core

| Stack | Server | Command / Transport | Role in DevFlow |
| :--- | :--- | :--- | :--- |
| **Angular** | **`angular-cli`** | `npx -y @angular/cli mcp` | Official Angular conventions (`get_best_practices`), zoneless migrations, local devserver lifecycle. |
| **Flutter** | **`dart`** | Community Dart MCP / Dart CLI tools | Symbol lookup, package APIs, SDK diagnostics and signatures. |
| **Next.js** | **`next-devtools`** | `npx -y next-devtools-mcp@latest` (connects to `/_next/mcp`) | Live dev errors (`get_errors`), routes (`get_routes`), Server Actions inspection. |
| **NestJS** | **`openapi`** | `npx -y @openapi-mcp/server` | OpenAPI/Swagger contract introspection, DTO and validation boundary checks. |
| **Web UI (Next / Angular)** | **`playwright`** | `npx -y @playwright/mcp@latest` | ARIA tree snapshots in `devflow.beautify` (a11y) and browser execution in `devflow.test` (Level 4 verify). |

### 3. Conditional Infrastructure (Add ONLY when used)

| Server | Condition | Command / Transport | Purpose |
| :--- | :--- | :--- | :--- |
| **`supabase`** | Project uses Supabase (`supabase_flutter`, `@supabase/*`, or Supabase backend) | Supabase MCP | Introspect remote schemas, tables, RLS policies during planning and migration verification. |
| **`postgres`** | Project connects directly to PostgreSQL (`pg`, TypeORM/Prisma postgres driver) | `npx -y mcp-postgres-server` or `@microsoft/postgres-mcp` | Read-only live schema check and index verification to prevent migration drifts. *(Note: deprecated `@modelcontextprotocol/server-postgres` is prohibited due to SQLi vulnerabilities)*. |
| **`sentry`** | Project uses Sentry for monitoring (`@sentry/*`, `sentry_flutter`) | `https://mcp.sentry.dev/sse` | Error triage, issue search, stack trace retrieval during `devflow.backprop`. |

---

## Client Configuration Examples

### Antigravity / Gemini IDE (`~/.gemini/config/mcp_config.json`)

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    },
    "next-devtools": {
      "command": "npx",
      "args": ["-y", "next-devtools-mcp@latest"]
    }
  }
}
```

### Claude Code (`~/.claude.json` or `.mcp.json`)

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
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

---

## Setup Integration (`devflow.setup`)

During `devflow.setup`:

1. Scans project dependencies (`package.json`, `pubspec.yaml`) and questionnaire answers (DB / backend decisions).
2. Generates the `{{mcp-baseline}}` value in `AGENTS.md` containing only the universal baseline + active stack core + detected infrastructure.
3. If an app does not use Supabase, `supabase` is excluded. If an app does not use PostgreSQL, `postgres` is excluded.
