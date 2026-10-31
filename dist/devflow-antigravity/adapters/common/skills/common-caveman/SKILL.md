---
name: common-caveman
description: Rewrite current response in caveman-speak — drop articles, filler, hedging; keep full technical accuracy. ~75% fewer output tokens. Use when user says caveman mode, talk like caveman, less tokens, or be brief. Single invocation — does not persist.
---

# Skill: common-caveman

## Purpose

Compress response into caveman-speak. Drop fluff. Keep substance. ~75% token reduction, 100% technical accuracy.

## When NOT to Use

- Security warning — write full sentences
- Irreversible destructive op (DROP TABLE, rm -rf, force push, branch delete) — confirm in normal prose
- Multi-step sequence where compression creates ordering ambiguity
- User asks clarification or repeats question
- Code, config or file content being written — prose output only; no adapter `steps/implement.md` → skill load decision matrix row loads it

Resume caveman right after a normal-prose exception.

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
- All negations, conditions, verbs, and attribution
- Genuine epistemic uncertainty (`~`, `unverified`) when citing unmeasured estimates — never invent facts or strip real caveats for brevity

**Patterns:** fragments OK. Short synonyms: fix/"big"/"use" over "implement a solution for"/"extensive"/"make use of". Structure: `[thing] [action] [reason]. [next step].` Arrows: `X → Y`

**Never abbreviate:**

- API names, function names, method names, class names, error strings
- Content inside code blocks

## Common Rationalizations

| Thought | Reality |
| --------- | --------- |
| "Answer complex — needs full sentence" | Complexity ≠ verbosity. Technical substance survives compression. |
| "Ambiguous without articles" | Add precision; removing "the" ≠ removing clarity. |
| "User won't understand fragments" | Exact technical terms + fragments = faster parse. |
| "Security topic — skip caveman" | Security topic ≠ warning. Destructive action → prose. Concept → caveman. |

## Examples

| Before | After |
| -------- | --------- |
| "The issue is that your component creates a new object reference on each render cycle." | "New object ref each render." |
| "I'd recommend wrapping it in `useMemo` to prevent unnecessary re-renders." | "Wrap in `useMemo`." |
| "You should consider adding a null check before accessing that property." | "Add null check before property access." |
| "The auth middleware fails because the token expiry check uses `<` instead of `<=`." | "Auth middleware: expiry check use `<` not `<=`." |
| "Connection pooling reuses open connections instead of creating new ones per request." | "Pool reuse open DB connections. No new connection per request. Skip handshake overhead." |

## I/O Reference

| | |
| --- | --- |
| Reads | Current response / pending output |
| Invoked by | User request; core skills' "caveman-compress" principle via `$HOME/.gemini/antigravity-cli/plugins/devflow/references/token-economy.md` |
| Writes | Compressed rewrite — same content, ~75% fewer tokens |
| Next step | None — single invocation |
