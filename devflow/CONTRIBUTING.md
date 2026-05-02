# Contributing to dev-flow

## Quality Bar

Skills must be:

- **Specific** — actionable steps, not vague guidance
- **Verifiable** — explicit input contract + completion checklist with evidence
- **Token-lean** — caveman-compress style; no filler, articles, hedging
- **Pipeline-integrated** — I/O Reference table; explicit reads/writes/next-step

## Adding a Pipeline Skill

Location: `devflow/skills/devflow-<name>/SKILL.md`

Required sections (in order):

1. YAML frontmatter — `name`, `description` (+ optional `argument-hint`, `disable-model-invocation`, `model`, `effort`)
2. `## Purpose` — one line; what it does, which pipeline step
3. `## When NOT to Use` — conditions routing agent elsewhere
4. `## Input contract` — checklist; fail-fast on any failure before touching files
5. `## Workflow` — numbered steps, concrete actions
6. `## Common Rationalizations` — table: excuses agents use + factual rebuttals
7. `## I/O Reference` — reads, writes, next step

Optional (add when needed):

- `## Anti-patterns` — behaviors not covered by rationalizations
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
3. Rewrite `ADAPTER.md` with stack rules (Technology skills table, MCP, commands, pre-handoff checklists per pipeline step)
4. Add technology skills under `adapters/<name>/skills/`
5. Add setup templates under `adapters/<name>/templates/` (`AGENTS.template.md`, `REGISTRY.template.md`, `PRODUCT.template.md`)
6. Document in root `README.md`

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Pipeline skill dir | `devflow-<name>` | `devflow-task` |
| Adapter skill dir | `<adapter>-<domain>` | `angular-forms` |
| Common skill dir | `common-<domain>` | `common-clean-code` |
| Command file | `devflow.<step>.md` | `devflow.task.md` |
| `SKILL.md` | Always uppercase | `SKILL.md` |
| `ADAPTER.md` | Always uppercase | `ADAPTER.md` |
| Feature directories | `NNN_<kebab-name>` | `003_user-profile` |

## Common Rationalizations (when writing skills)

| Thought | Reality |
|---------|---------|
| "This skill doesn't need an input contract" | Skills fail-fast on bad input. No contract → silent partial execution |
| "Long content can stay in SKILL.md" | Content over 100 lines → `references/<file>.md`. Link from SKILL.md |
| "I'll describe what code should look like" | Skills are workflows agents follow, not reference docs |
| "Rationalizations section is optional" | Rationalizations prevent most common failure modes. Always include with factual counters |
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

**Hook vs skill:**
- Hook: automated, runs on every tool call/session event, no user invocation needed
- Skill: invoked explicitly by user or another skill, contains workflow guidance for Claude

**Available events:**

| Event | Notes |
|---|---|
| `SessionStart` | Fires once at session start; use for context injection |
| `PreToolUse` | Fires before a tool call; block with `{"decision":"block","reason":"..."}` on stdout |
| `PostToolUse` | Fires after a tool call; async OK; do not emit stdout (no passthrough) |
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

## What Not to Do

- No duplicate content between skills — reference other skills
- No vague advice skills — actionable workflows only
- No reference material in `SKILL.md` over 100 lines — use `references/`
- No adapter skills contradicting `ADAPTER.md` — ADAPTER.md is SSOT for stack behavior
