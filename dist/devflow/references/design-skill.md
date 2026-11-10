# Design Skill — impeccable

Sole owner of how DevFlow hands UI design work to [impeccable](https://github.com/pbakaus/impeccable) (Apache-2.0, external — never vendored). Skills that touch design (`devflow.setup`, `devflow.plan`, `devflow.implement`) follow this file; never restate detection or routing inline.

## Availability

- **Available** — skill `impeccable` listed among host's available skills (Claude Code: `impeccable` or `impeccable:impeccable`; Antigravity: `impeccable`)
- **UI adapter** — `angular`, `nextjs`, `flutter` (impeccable covers web + native iOS/Android). `nestjs` → never applies
- Not available → DESIGN.md-only behavior (`DESIGN.md` / `docs/design.md` tokens), zero behavior change. Never install mid-pipeline — only `devflow.setup` installs (**Install** below); `devflow.doctor` reports

## Install (devflow.setup, UI adapter only)

Automatic, no question — UI adapter chosen = consent. Once per repo (monorepo: repo root, never per app), project scope so teammates get it from git. Pick first route that applies:

| Route | When | Command (repo root) |
| --- | --- | --- |
| npx | `node` on PATH | `npx -y impeccable install --yes --providers=<claude\|antigravity> --scope=project` → `.claude/skills/impeccable/` or `.agent/skills/impeccable/` |
| plugin CLI | Claude Code, no `node` | `claude plugin marketplace add pbakaus/impeccable --scope project` then `claude plugin install impeccable@impeccable --scope project` → `.claude/settings.json` |
| none | Antigravity, no `node` | No install — hint `npx impeccable install` in notify block |

- Provider = current host (`claude` on Claude Code, `antigravity` on Antigravity). Design hook kept (impeccable default; Claude Code only)
- Exit ≠ 0 → no retry loop: report command + decisive error line, continue setup (DESIGN.md-only fallback)
- Success → notify block lists: files to commit (`.claude/skills/impeccable/` / `.agent/skills/impeccable/` or `.claude/settings.json`), `.impeccable/` runtime entries per impeccable README `.gitignore` block, telemetry opt-out (`npx impeccable telemetry off` or `DO_NOT_TRACK=1`)
- Skill not listed in current session after install (host loads skills at start; plugin route needs `/reload-plugins`) → do not invoke it; notify: `/reload-plugins` or restart, then `/impeccable init` + `/impeccable document`

## Context files (impeccable-owned)

| File | Written by | Holds |
| --- | --- | --- |
| `PRODUCT.md` (root) | `/impeccable init` | Brand, audience, platform — impeccable's design context |
| `DESIGN.md` (root) + `.impeccable/design.json` | `/impeccable document` | Visual system: palette, typography, spacing, components |

`PRODUCT.md` ≠ `docs/product.md`: DevFlow's file holds features/domain; impeccable's holds design brief. Never merge, never write one from the other. DevFlow never edits either impeccable file — rerun the impeccable command instead.

## Routing by step

| Step | When | Action |
| --- | --- | --- |
| `devflow.setup` | UI adapter | Not available → **Install**. Then available · `PRODUCT.md` or `DESIGN.md` missing → offer once: `Run /impeccable init (PRODUCT.md) + /impeccable document (DESIGN.md) now?` Yes → invoke skill `impeccable` with `init`, then `document` (both interactive) |
| `devflow.plan` Step 4e | UI files in feature · (`DESIGN.md` present **or** available) | Tag UI File List entries `[ui]`; note design source in **Architecture decisions** |
| `devflow.implement` | batch with `[ui]` entries · available | Invoke skill `impeccable` per **Implement brief** below before writing those files |

Commands never run from DevFlow: `live`, `generate` (browser loop, needs dev server), `shape` (plan already decided scope), `critique` / `audit` / `polish` (out of selected scope — user runs them manually).

## Implement brief

Invoke skill `impeccable` (bare request, no sub-command — impeccable routes new surfaces itself) with:

- Target: `[ui]` File List entries of current batch (exact paths) + one-line goal from `plan.md`
- Constraints: acceptance criteria touching UI, `constitution.md` layering, `REGISTRY.md` shared components to reuse
- Boundary: write only listed paths; no new dependencies; no files outside File List

Ownership split:

- **impeccable** — visual decisions: layout, hierarchy, typography, color, spacing, motion, states (empty/loading/error), anti-slop
- **DevFlow** — scope (File List), architecture, data flow, tests, verify stamps. Conflict → DevFlow wins; impeccable suggestion outside File List → `FYI:` in implement notify, not a new file

`DESIGN.md` present → impeccable reads it itself; do not also load it as separate constraints (one source, no duplicate tokens in context).

## Run mode (`.devflow-run.json` present)

impeccable `init` / `document` / `shape` ask questions — no answer channel exists. Therefore:

- `PRODUCT.md` missing → skip impeccable (impeccable would route through interactive `init`); use `DESIGN.md` fallback; log `## Decision flags` entry `design-skill: skipped — PRODUCT.md missing` per `@devflow/references/run-mode.md`
- `PRODUCT.md` present → invoke with brief; any impeccable question → answer from `plan.md` / `task.md` / `PRODUCT.md`; no answer there → most conservative option (reuse existing pattern) + Decision flags entry
- Never run `init`, `document`, `shape`, `live`, `generate`
