#!/usr/bin/env bash
# create-adapter.sh — Scaffolds a new compliant DevFlow adapter skeleton
# Usage: bash scripts/create-adapter.sh <adapter-name>
# Example: bash scripts/create-adapter.sh fastapi
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADAPTERS_DIR="$ROOT_DIR/templates/devflow/adapters"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/create-adapter.sh <adapter-name>"
  echo "Example: bash scripts/create-adapter.sh fastapi"
  exit 1
fi

NAME="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

if [[ ! "$NAME" =~ ^[a-z0-9-]+$ ]]; then
  echo "ERROR: adapter name must contain only lowercase letters, digits, and hyphens (got: $NAME)"
  exit 1
fi

TARGET_DIR="$ADAPTERS_DIR/$NAME"

if [[ -d "$TARGET_DIR" ]]; then
  echo "ERROR: adapter directory already exists at $TARGET_DIR"
  exit 1
fi

echo "Scaffolding new DevFlow adapter: '$NAME'..."

mkdir -p "$TARGET_DIR/steps"
mkdir -p "$TARGET_DIR/templates"
mkdir -p "$TARGET_DIR/skills/$NAME-architecture"

CAP_NAME="$(tr '[:lower:]' '[:upper:]' <<< "${NAME:0:1}")${NAME:1}"

# ── 1. ADAPTER.md ─────────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/ADAPTER.md"
# $CAP_NAME adapter (DevFlow)

Single source of truth for $CAP_NAME behavior. Pipeline skills (\`devflow-plan\`, \`devflow-implement\`, \`devflow-beautify\`, \`devflow-test\`, \`devflow-pr\`) **must** read \`@devflow/config.md\`, resolve adapter, then load this core file **plus** the \`steps/<step>.md\` file for the active step (see **Step files** below). Do not load step files for other steps.

Baseline: **$CAP_NAME**. Keep output token-lean and imperative.

## Technology skills (load by feature type)

| When | Load |
| --- | --- |
| App structure, module boundaries, architectural layout | \`@devflow/adapters/$NAME/skills/$NAME-architecture/SKILL.md\` |

## MCP (when available)

- Required baseline for this adapter:
  - \`context7\`
  - \`sequential-thinking\` (MCP server: <https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking>)
- Conditional (only when used in project):
  - \`sentry\` (\`mcp.sentry.dev\` / \`getsentry/sentry-mcp\`) — error triage and stack traces

## Caveman response rules (mandatory)

Apply to narrative text in plans, updates, reviews, PR notes:

- Drop: articles, filler (\`just/really/basically/actually/simply\`), pleasantries, hedging.
- Keep: technical terms exact, code blocks unchanged.
- Prefer: \`fix\`, \`use\`, \`build\`, \`test\`. Pattern: \`[thing] [action] [reason]. [next step].\`

## Step files (load only the active step)

| Step | File | Contains |
| --- | --- | --- |
| setup | \`steps/setup.md\` | Setup templates + dependencies |
| plan | \`steps/plan.md\` | Plan extra sections and templates |
| implement | \`steps/implement.md\` | Skill load decision matrix, commands, checklist |
| beautify | \`steps/beautify.md\` | Beautify commands, review axes, accessibility checks |
| test | \`steps/test.md\` | Test layout, commands, coverage threshold, verify |
| pr | \`steps/pr.md\` | PR verification and body checklist |
EOF

# ── 2. steps/setup.md ─────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/steps/setup.md"
# $CAP_NAME adapter — Setup step

Loaded by \`devflow-setup\` together with the adapter core (\`ADAPTER.md\`).

## Setup: templates

\`devflow.setup\` uses adapter templates first, then global fallback:

- \`@devflow/adapters/$NAME/templates/AGENTS.template.md\`
- \`@devflow/adapters/$NAME/templates/REGISTRY.template.md\`
- \`@devflow/adapters/$NAME/templates/CONSTITUTION.template.md\`

Template intent:

- \`AGENTS.template.md\`: short operational rules + skill references (\`@...\`) only.
- \`REGISTRY.template.md\`: compact pattern registry and core conventions.
- \`CONSTITUTION.template.md\`: architectural invariants and stack baseline.

Output must stay token-lean, imperative, filler-free.

## Setup dependencies

Dependencies below are authoritative for \`devflow.setup\` auto-install.

### $NAME-dependencies

- # Add runtime packages here

### $NAME-dev-dependencies

- # Add dev/test packages here
EOF

# ── 3. steps/plan.md ──────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/steps/plan.md"
# $CAP_NAME adapter — Plan step

Loaded by \`devflow-plan\` together with the adapter core (\`ADAPTER.md\`).

## Plan: extra sections and templates

Include these in \`plan.md\` when applicable (after core sections from \`devflow-plan\`).

### Dependency ordering (layering)

Order the **File list** bottom-up by layer ownership:

1. Core configuration, types, and schemas
2. Database entities, migrations, and persistence layer
3. Service layer / business logic
4. Entry points (routes, controllers, CLI, UI)
5. Unit and integration tests
EOF

# ── 4. steps/implement.md ─────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/steps/implement.md"
# $CAP_NAME adapter — Implement step

Loaded by \`devflow-implement\` together with the adapter core (\`ADAPTER.md\`).

## Implement: skill load decision matrix

When implementing files, load technology skills based on file path patterns:

| File path pattern | Load skill |
| --- | --- |
| \`**/*\` | \`$NAME-architecture\` |

Load only the skills triggered by the current batch's file paths. Do not load all skills preemptively.

## Implement: commands and checklist

### Format, lint, analyze, build

Run after substantive edits, in order:

\`\`\`bash
# Add format/lint/check commands here
\`\`\`

Retry failed steps up to **3** attempts each; then stop and report full output.

### Pre-handoff checklist (implement)

- [ ] Lint, analyze, build pass (or failures documented)
- [ ] Relevant $CAP_NAME skills loaded and applied for touched areas
- [ ] Architecture constraints verified against \`$NAME-architecture\`
EOF

# ── 5. steps/beautify.md ──────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/steps/beautify.md"
# $CAP_NAME adapter — Beautify step

Loaded by \`devflow-beautify\` together with the adapter core (\`ADAPTER.md\`).

## Beautify: commands

Same as implement pipeline: format, lint, analyze.

### Beautify: $CAP_NAME-specific review axes

Apply core \`devflow-beautify\` axes, then evaluate touched code:

- Architectural boundaries and module separation
- Idiomatic language and framework conventions
- Clean error handling and logging discipline

### Beautify: accessibility checks

Apply accessibility checks relevant to this stack:

- UI stacks: WCAG 2.1 AA keyboard/screen reader/contrast compliance.
- API/Backend stacks: RFC 7807 problem details, clear status codes, OpenAPI schema parity.

### Beautify: performance profiling trigger

Profile only when the plan calls out performance or a **Critical**-severity hotspot is flagged:

- Avoid premature micro-optimizations. Profile before refactoring.
EOF

# ── 6. steps/test.md ──────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/steps/test.md"
# $CAP_NAME adapter — Test step

Loaded by \`devflow-test\` (and \`devflow-backprop\` for test conventions) together with the adapter core (\`ADAPTER.md\`).

## Test: layout and commands

### Coverage threshold

\`test-coverage-threshold: 80\`

Any feature leaving public surfaces below this threshold must be called out explicitly in the Step 2b gap report.

### Placement

- Unit: colocated test files or mirrored \`tests/unit/\`.
- Integration: \`tests/integration/\` or \`tests/e2e/\`.

### Commands

\`\`\`bash
# Add test runner command here
\`\`\`

### Verify (runtime)

Level-4 goal-backward verification target (\`devflow.test\` Step 6b):

\`\`\`bash
# Add runtime verification command here
\`\`\`
EOF

# ── 7. steps/pr.md ────────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/steps/pr.md"
# $CAP_NAME adapter — PR step

Loaded by \`devflow-pr\` together with the adapter core (\`ADAPTER.md\`).

## PR: verification

Before push:

\`\`\`bash
# Add pre-push verification commands here
\`\`\`

### PR body checklist (copy into PR description)

- [ ] Lint passing
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Build passing
- [ ] \`$NAME-architecture\` constraints respected
- [ ] \`registry.md\` updated if new patterns were introduced
EOF

# ── 8. templates/ ─────────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/templates/AGENTS.template.md"
# Project Rules ($CAP_NAME)

<!-- devflow-managed: agents -->
## Agent Operating Rules

- Required MCP baseline: {{mcp-baseline}}
- Architecture: see \`constitution.md\`
- Technology skills:
  - \`@devflow/adapters/$NAME/skills/$NAME-architecture/SKILL.md\`
<!-- /devflow-managed: agents -->
EOF

cat <<EOF > "$TARGET_DIR/templates/REGISTRY.template.md"
# Pattern Registry ($CAP_NAME)

<!-- devflow-managed: registry -->
## Conventions & Patterns

Document shared project conventions here.
<!-- /devflow-managed: registry -->
EOF

cat <<EOF > "$TARGET_DIR/templates/CONSTITUTION.template.md"
# Architecture Constitution ($CAP_NAME)

## Core Stack

- Framework: $CAP_NAME

## Architectural Principles

1. Modular boundaries
2. Spec-driven development
EOF

# ── 9. skills/ ────────────────────────────────────────────────────────────────
cat <<EOF > "$TARGET_DIR/skills/$NAME-architecture/SKILL.md"
---
name: $NAME-architecture
description: App structure, folder layout, boundaries, and conventions for $CAP_NAME applications. Use when planning or implementing $CAP_NAME architectural boundaries.
disable-model-invocation: true
---

# Skill: $NAME-architecture

## Purpose

Defines project structure, layer separation, and architectural boundaries for $CAP_NAME projects.

## Core Principles

- **layer-separation** — clear distinction between domain, data, and presentation/transport
- **single-responsibility** — one primary concern per file or module
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## I/O Reference

| Inputs | Outputs |
| --- | --- |
| Feature requirements, existing folder tree | Scaffolding plan, file tree layout, module boundaries |

## Anti-Patterns

- Circular dependencies across modules
- Direct data access in controller/handler layers

## Workflow

1. Inspect project layout and boundaries
2. Place new feature code within the designated layer
3. Verify imports respect directional architecture rules
EOF

echo "✓ Adapter '$NAME' scaffolded at templates/devflow/adapters/$NAME"
echo ""
echo "Running schema audit..."
bash "$ROOT_DIR/templates/devflow/scripts/validate-adapters.sh"
