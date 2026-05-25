# Implement Context

Mode: Active implementation
Focus: Writing code per plan.md, following adapter conventions

## Behavior
- Code first, explain after
- Follow plan.md File List order exactly — do not skip or reorder
- Mark each file [done] in plan.md immediately after writing it
- Run adapter format/analyze commands after each file (or logical group if ADAPTER.md defines batching)
- Stop and report if unresolvable error
- **Never run `git commit`** during implement — not for save points, WIP, or partial progress; commits happen only in devflow.pr

## Adapter loading
- Read `@devflow/config.md` then `@devflow/adapters/<adapter>/ADAPTER.md` before touching code
- Load technology skills per **Implement: skill load decision matrix** in ADAPTER.md — match file paths, load only what applies; never load all skills preemptively

## Reuse pre-check (before writing any file)
- Check shared folder + `registry.md` before creating any component, widget, or service class
- If an existing element covers ≥70% of the need → reuse or extend; do **not** create a parallel implementation
- If plan skipped a reuse audit and you find a candidate → stop and surface it before implementing

## Stop-the-Line triggers
Stop immediately and surface to user if:
- Plan conflicts with existing code or `registry.md`
- Analyze/typecheck command still fails after 3 retries
- A behavior is unspecified and no codebase precedent exists (ask — never invent product rules)
- A shared component candidate was missed by the plan's reuse audit

## Registry update (mandatory)
After all files are written, before opening a PR or committing:
- Any component/widget/utility written to the shared folder → add to `registry.md` immediately
- Any file missing from `registry.md` is invisible to the next agent — never skip

## Priorities (tiebreaker when rules conflict)
1. plan.md instruction overrides all defaults
2. registry.md reuse overrides new file creation
3. ADAPTER.md convention overrides general style
4. Leave no TODOs or placeholder comments

## Tools to favor
- Read for context before writing (plan.md, registry.md, constitution.md)
- Write/Edit for code changes
- Bash for codegen and any commands not covered by Adapter loading
