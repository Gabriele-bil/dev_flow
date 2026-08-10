# Contributing to dev-flow

## Quality Bar

Skills must be:

- **Specific** — actionable steps, not vague guidance
- **Verifiable** — explicit input contract + completion checklist with evidence
- **Token-lean** — caveman-compress style; no filler, articles, hedging
- **Derive, don't dump** — skills running commands state derived answer + decisive lines, never wholesale output paste (`references/token-economy.md`)
- **Pipeline-integrated** — I/O Reference table; explicit reads/writes/next-step

## Choosing a Mechanism

Three mechanisms, three jobs. Don't blur them.

| Mechanism | Use for | Control | Example |
| --- | --- | --- | --- |
| **Hook** | Must run every time, no exceptions — safety, formatting, config protection | Deterministic — shell script, exit code decides | `pre-bash-destructive-guard.sh` blocks `rm -rf /` unconditionally |
| **Skill** | Needs judgment, context, multi-step reasoning | Probabilistic — Claude follows workflow guidance | `devflow-ship` weighs findings, asks user on Critical |
| **Command** | Thin entry point, no logic of its own | N/A — dispatches only | `devflow.ship.md`: "Use `@devflow/skills/devflow-ship/SKILL.md` and execute it exactly" |

Rule of thumb: if skipping the check even once is unacceptable, it's a hook, not a skill instruction. Skills can be misread or rationalized around; hooks can't. Never put a hard safety rule only in skill prose — a determined agent (or a bad day) will talk itself past it. See Anthropic's "Steering Claude Code: Skills, Hooks, Rules, Subagents and More" for the underlying deterministic-vs-probabilistic framework.

## Adding a Pipeline Skill

Location: `devflow/skills/devflow-<name>/SKILL.md`

Required sections (in order):

1. YAML frontmatter — `name`, `description` (+ optional `argument-hint`, `disable-model-invocation`, `model`, `effort`)
2. `## Purpose` — one line; what it does, which pipeline step
3. `## Core Principles` — copy exact 4-bullet block from `ETHOS.md`; do not paraphrase
4. `## When NOT to Use` — conditions routing agent elsewhere
5. `## Input contract` — checklist; fail-fast on any failure before touching files
6. `## Workflow` — numbered steps, concrete actions
7. `## Common Rationalizations` — table: excuses agents use + factual rebuttals
8. `## Anti-Patterns` — table: wrong approach + problem + correct behavior; distinct from rationalizations
9. `## I/O Reference` — reads, writes, next step

Also add `evals/cases/<skill-name>.json` — at least 3 positive trigger
prompts and 2 negative trigger prompts (paraphrased user asks, not copied
from `description:`). Skip if the skill sets `disable-model-invocation:
true` — see `evals/README.md`.

Optional (add when needed):

- `## Completion checklist` — exit criteria before notify step

## Adding an Adapter Skill

Location: `devflow/adapters/<adapter>/skills/<adapter>-<domain>/SKILL.md`

Additional requirements:

- File path trigger documented in `ADAPTER.md` → **Technology skills** table
- `## When NOT to Use` includes: "file does not match trigger pattern in `ADAPTER.md`"
- Content over 100 lines → extract to `references/<file>.md` in skill directory; link from `SKILL.md`
- No duplication of `common-clean-code` or other common skills — reference them

## Adding a New Adapter

1. Copy `adapters/flutter/` as template
2. Rename to `adapters/<name>/`
3. Rewrite `ADAPTER.md` (core: Technology skills table, MCP, step-files index) and the `steps/*.md` files (per-step commands, plan sections, checklists — one file per pipeline step: setup, plan, implement, beautify, test, pr)
4. Add technology skills under `adapters/<name>/skills/`
5. Add setup templates under `adapters/<name>/templates/` (`AGENTS.template.md`, `REGISTRY.template.md`, `PRODUCT.template.md`)
6. Document in root `README.md`

Adapters stay single-stack and path-agnostic — never add monorepo-aware branching inside an adapter contract. Monorepo composition (which apps exist, which adapter each uses, which app a feature targets) lives entirely in `devflow/config.md`'s `## Apps` table, `task.md`/`plan.md`'s `**App:**` field, and `@devflow/references/adapter-resolution.md` — not in `ADAPTER.md`.

## Monorepo Support

DevFlow supports monorepos with multiple applications, each on its own adapter. This is zero-migration for existing single-app repos: absence of a `## Apps` table in `devflow/config.md` means single-app behavior, byte-identical to before.

- `devflow/config.md` gains an optional `**Mode:** monorepo` line + `## Apps` table (`App | Path | Adapter | Adapter root`), written by `devflow-setup`. Apps are declared explicitly by the user during setup — never auto-scanned or inferred from folder conventions like `apps/<name>/`.
- `task.md` and `plan.md` gain an optional `**App:**` header field — the single source of truth for which app a feature targets. Set once in `devflow-task` (asked, or via `--app <name>`), then propagated verbatim by `devflow-plan` into `plan.md`; every downstream skill reads it from `plan.md`, never re-resolves it from `task.md`.
- **Any skill that needs to know the active adapter or app working directory must resolve it via `@devflow/references/adapter-resolution.md`** — never inline a `**Adapter:**` grep or hardcode a single adapter assumption. That file is the sole owner of mode detection, adapter/app resolution, and the working-directory scoping rule (`(cd "<app-path>" && <command>)`).
- Template files (`AGENTS.template.md`, `REGISTRY.template.md`, `PRODUCT.template.md`, `CONSTITUTION.template.md`) are never forked per mode — all monorepo rendering logic (per-app constitution blocks, pointer lines instead of duplicated tables) lives in `devflow-setup/SKILL.md` prose, per the hook-vs-skill business-logic rule above.
- Missing `**App:**` on a monorepo feature is a hard stop, never a guess — surface it and ask.

## Naming Conventions

| Type | Convention | Example |
| ------ | ----------- | --------- |
| Pipeline skill dir | `devflow-<name>` | `devflow-task` |
| Adapter skill dir | `<adapter>-<domain>` | `angular-forms` |
| Common skill dir | `common-<domain>` | `common-clean-code` |
| Command file | `devflow.<step>.md` | `devflow.task.md` |
| `SKILL.md` | Always uppercase | `SKILL.md` |
| `ADAPTER.md` | Always uppercase | `ADAPTER.md` |
| Feature directories | `NNN_<kebab-name>` | `003_user-profile` |

## Common Rationalizations (when writing skills)

| Thought | Reality |
| --------- | --------- |
| "This skill doesn't need an input contract" | Skills fail-fast on bad input. No contract → silent partial execution |
| "Long content can stay in SKILL.md" | Content over 100 lines → `references/<file>.md`. Link from SKILL.md |
| "I'll describe what code should look like" | Skills are workflows agents follow, not reference docs |
| "Rationalizations section is optional" | Rationalizations prevent most common failure modes. Always include with factual counters |
| "Anti-patterns section is optional" | Anti-patterns document failure modes not covered by rationalizations — recurring wrong approaches that look correct |
| "Keep verbose prose from previous version" | Caveman-compress mandatory. Rewrite filler-heavy sections on touch |

## Style Guide: Caveman-Compress

Drop: articles (`a`, `the`, `an`), hedging (`should`, `might`, `consider`, `try`), filler (`basically`, `simply`, `just`, `note that`), linking phrases (`in order to`, `make sure to`).

Keep: technical terms exact, file paths exact, commands exact, all verbs, negations, conditions.

**Wrong:** "You should consider reading the constitution file before starting to implement any code"
**Right:** "Read `constitution.md` before implement"

**Wrong:** "It might be a good idea to avoid hardcoding color values in your components"
**Right:** "No hardcoded color values — use design-system tokens"

## Modifying Existing Skills

- Keep changes minimal and focused
- Preserve caveman-compress style throughout
- Verify YAML frontmatter valid after edits
- Update `## I/O Reference` if reads or writes change
- New rationalization entry requires factual counter — not restatement of problem

## Adding Hooks

Hook vs skill vs command — see **Choosing a Mechanism** above.

**Available events:**

| Event | Notes |
| --- | --- |
| `SessionStart` | Fires once at session start; use for context injection |
| `PreToolUse` | Fires before a tool call; block with `{"decision":"block","reason":"..."}` on stdout |
| `PostToolUse` | Fires after a tool call; async hooks emit no stdout; sync hooks may emit control JSON — `hookSpecificOutput.updatedToolOutput` rewrites tool output in context (cap 10k chars) |
| `PreCompact` | Fires before context compaction; output becomes part of compacted context |
| `Stop` | Fires after each Claude response; reads full response on stdin, must write it back on stdout (passthrough); async hooks skip passthrough requirement |
| `SessionEnd` | Fires when session closes; async OK |

**Script conventions:**

- No `set -e` — hooks must never crash the Claude session
- Always consume stdin: `RAW=$(cat)` — do not leave stdin open
- Stop hooks: always `printf '%s' "$RAW"` at the end (passthrough)
- Async hooks: add `"async": true, "timeout": N` in hooks.json
- Guard with `|| true` on all fallible commands
- Require `jq`? Check availability first: `command -v jq >/dev/null 2>&1 || exit 0`
- Runtime artifacts (`.tmp`, `.jsonl`, `.json`): append to `.gitignore` if `.gitignore` exists

**Naming convention:** `<event>-<purpose>.sh` — e.g. `pre-config-protect.sh`, `stop-format-typecheck.sh`

## Managed-Section Discipline (writes into consumer files)

Any skill writing DevFlow content into consumer-owned files (`AGENTS.md`, `constitution.md`, settings):

- Wrap owned content in `<!-- devflow-managed:start:<section-id> -->` / `<!-- devflow-managed:end:<section-id> -->`
- Re-run replaces exactly the fenced region; user head/tail content preserved byte-for-byte; never append second copy
- Markers absent but DevFlow-looking content present → surface conflict to user; never guess, never duplicate
- Removal deletes fenced region only; delete file only if empty after removal
- Add/remove exactly what you own — never clobber neighbouring user/tool sections; clean up empty parent keys only

**Behavioral tests (required):** every hook manipulating consumer state gets a suite in `hooks/tests/test-<purpose>.sh` (plain bash asserts, temp-dir fixtures — copy structure from `test-pre-compact.sh`). Run all suites: `bash scripts/run-hook-tests.sh`. `bash -n` alone is not coverage.

## What Not to Do

- No duplicate content between skills — reference other skills
- No vague advice skills — actionable workflows only
- No reference material in `SKILL.md` over 100 lines — use `references/`
- No adapter skills contradicting `ADAPTER.md` + `steps/*.md` — the adapter contract (core + step files) is SSOT for stack behavior
