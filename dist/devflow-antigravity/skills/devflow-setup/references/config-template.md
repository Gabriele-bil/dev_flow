# Setup config.md write templates

Used by `devflow.setup` Step 1 — overwrite `@devflow/config.md` with one of these, matching the resolved mode.

## Single app

```markdown
# DevFlow Configuration

**Adapter:** <adapter>  
**Adapter root:** `devflow/adapters/<adapter>/`

Pipeline skills read this file first, then load `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/ADAPTER.md` (core: technology skills, MCP) plus `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/steps/<step>.md` for the active step's commands, plan sections, and checklists.
```

## Monorepo

```markdown
# DevFlow Configuration

**Mode:** monorepo

## Apps

| App | Path | Adapter | Adapter root |
| --- | --- | --- | --- |
| web | `apps/web/` | nextjs | `devflow/adapters/nextjs/` |
| mobile | `apps/mobile/` | flutter | `devflow/adapters/flutter/` |

Pipeline skills resolve the active app from the current feature's `plan.md`/`task.md` **App:** field, look up its row above for adapter + path, then load `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/ADAPTER.md` (core) plus `$HOME/.gemini/antigravity-cli/plugins/devflow/adapters/<adapter>/steps/<step>.md`. All adapter shell commands run with working directory = that app's Path. Resolution algorithm: `$HOME/.gemini/antigravity-cli/plugins/devflow/references/adapter-resolution.md`.
```
