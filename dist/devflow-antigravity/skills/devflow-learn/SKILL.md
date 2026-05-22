---
name: devflow-learn
description: Manage DevFlow learnings log (.devflow-learnings.jsonl). Log project quirks, search past lessons, prune stale entries. Use when the user asks to log a finding, search past learnings, or clean up the learnings log.
argument-hint: [log, search, list, prune]
---

# Skill: devflow.learn

## Purpose

Read, write, and maintain `.devflow-learnings.jsonl` — the project's persistent lesson log. Complements the auto-detected signals written by the `stop-learn-distill` hook.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Pipeline step execution — use `devflow.task`, `devflow.plan`, etc. instead
- First-time project setup — use `devflow.setup` instead

## Workflow

Identify the sub-command from user message or argument, then execute it.

---

### Sub-command: log

Record a manual learning (quirk, lesson, or warning) that should inform future sessions.

**Step 1 — Collect information**

Ask (if not provided):
1. What module or file does this apply to? (optional)
2. What is the lesson in one sentence? (required)
3. Type: `quirk` (unexpected behaviour), `lesson` (better approach found), or `warning` (known fragile area)?

**Step 2 — Write entry**

Run:

```bash
jq -cn \
  --arg ts      "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg feature "$(jq -r '.feature // empty' .devflow-state.json 2>/dev/null || true)" \
  --arg step    "$(jq -r '.next_step // empty' .devflow-state.json 2>/dev/null || true)" \
  --arg type    "<TYPE>"   \
  --arg file    "<FILE>"   \
  --arg note    "<NOTE>"   \
  '{
    ts:      $ts,
    type:    $type,
    source:  "manual",
    feature: (if $feature != "" then $feature else null end),
    step:    (if $step    != "" then $step    else null end),
    file:    (if $file    != "" then $file    else null end),
    note:    $note
  } | with_entries(select(.value != null))' \
  >> .devflow-learnings.jsonl
```

Confirm: "Learning logged."

---

### Sub-command: search

Find past learnings matching a keyword.

**Step 1 — Run search**

```bash
jq -r \
  --arg q "<QUERY>" \
  'select((.note + " " + (.file // "") + " " + (.feature // "")) | ascii_downcase | contains($q | ascii_downcase)) | "[\(.ts[0:10])] [\(.type)] \(if .file then .file + ": " else "" end)\(.note)"' \
  .devflow-learnings.jsonl 2>/dev/null
```

**Step 2 — Display results**

If no output: "No learnings matching `<QUERY>`."
Otherwise: show results, grouped by type if >5 results.

---

### Sub-command: list

Show all learnings, most recent first (max 20).

```bash
jq -rs 'sort_by(.ts) | reverse | .[0:20] | .[] | "[\(.ts[0:10])] [\(.type)] \(.source) — \(if .file then .file + ": " else "" end)\(.note)"' \
  .devflow-learnings.jsonl 2>/dev/null
```

If file missing or empty: "No learnings recorded yet for this project."

---

### Sub-command: prune

Remove entries older than 30 days (keep all `source: manual` entries regardless of age).

**Step 1 — Compute cutoff**

```bash
# macOS
CUTOFF=$(date -v -30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) \
  || CUTOFF=$(date -d "-30 days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) \
  || CUTOFF=""
```

**Step 2 — Filter and overwrite**

```bash
jq -rs \
  --arg cutoff "$CUTOFF" \
  '[.[] | select(.source == "manual" or ($cutoff == "") or (.ts >= $cutoff))]
   | .[]' \
  .devflow-learnings.jsonl > .devflow-learnings.tmp \
  && mv .devflow-learnings.tmp .devflow-learnings.jsonl
```

Report: "Pruned <N> entries. <M> entries remain."

---

## I/O Reference

| | |
|---|---|
| Reads | `.devflow-learnings.jsonl`, `.devflow-state.json` |
| Writes | `.devflow-learnings.jsonl` |
| Related | `stop-learn-distill` hook (auto-signals), `session-start-learnings` hook (injection) |
