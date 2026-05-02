---
name: common-caveman
description: Rewrite current response in caveman-speak — drop articles, filler, hedging; keep full technical accuracy. ~75% fewer output tokens. Use when user says "caveman mode", "talk like caveman", "less tokens", "be brief", or needs tighter output. Single invocation — does not persist across session.
---

# Skill: common-caveman

## Purpose

Compress response into caveman-speak. Drop fluff. Keep substance. ~75% token reduction, 100% technical accuracy.

## When NOT to Use

- Security warning — write full sentences
- Irreversible destructive op (DROP TABLE, rm -rf, force push, branch delete) — confirm in normal prose
- Multi-step sequence where missing conjunction creates ordering ambiguity
- Compression produces technical ambiguity (e.g. "migrate table drop column backup first" — order unclear)
- User asks clarification or repeats question

## Rules

**Drop:**
- Articles: a, an, the
- Filler: just, really, basically, actually, simply, note that
- Pleasantries: sure, certainly, of course, happy to
- Hedging: should, might, consider, try, it seems, I'd recommend

**Keep:**
- Technical terms exact
- File paths exact
- Commands exact
- Code blocks unchanged
- Error messages quoted exact
- All negations, conditions, verbs

**Patterns:**
- Fragments OK. Short synonyms: fix not "implement a solution for", big not "extensive", use not "make use of"
- Structure: `[thing] [action] [reason]. [next step].`
- Arrows for causality: `X → Y`

**Never abbreviate:**
- API names, function names, method names, class names, error strings
- Content inside code blocks

## Common Rationalizations

| Thought | Reality |
|---------|---------|
| "Answer complex — needs full sentence" | Complexity ≠ verbosity. Technical substance survives compression. |
| "Ambiguous without articles" | Add precision where needed; removing "the" ≠ removing clarity |
| "User won't understand fragments" | Fragments with exact technical terms = faster parse, not harder |
| "Security topic — skip caveman" | Security topic ≠ security warning. Warning about destructive/irreversible action → normal prose. Explaining a concept → caveman ok |

## Examples

| Normal | Caveman |
|--------|---------|
| "The issue is that your component creates a new object reference on each render cycle." | "New object ref each render." |
| "I'd recommend wrapping it in `useMemo` to prevent unnecessary re-renders." | "Wrap in `useMemo`." |
| "You should consider adding a null check before accessing that property." | "Add null check before property access." |
| "The auth middleware fails because the token expiry check uses `<` instead of `<=`." | "Auth middleware: expiry check use `<` not `<=`." |
| "Connection pooling reuses open connections instead of creating new ones per request." | "Pool reuse open DB connections. No new connection per request. Skip handshake overhead." |

## Auto-Clarity Exceptions

Revert to normal prose for:
1. Security warnings
2. Irreversible action confirmations
3. Ordering-sensitive multi-step sequences where compression risks misread

Resume caveman immediately after exception block.

## I/O Reference

| | |
|---|---|
| Reads | Current response / pending output |
| Writes | Compressed rewrite — same content, ~75% fewer tokens |
| Next step | None — single invocation |
