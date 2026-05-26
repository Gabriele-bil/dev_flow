# Instinct Learning System — Design Spec

**Date:** 2026-05-26  
**Status:** Approved  
**Scope:** `templates/devflow/` — hooks + skill only; no Python; no global scope (v1)

---

## Problem

The current `.devflow-learnings.jsonl` format is free-form and unfocused. Entries lack structured triggers, confidence scores, or actionability. Session injection surfaces raw notes with no relevance ranking. Auto-detection is limited to file-churn signals only.

---

## Goal

Replace the free-form JSONL log with **atomic YAML instincts** — structured, confidence-weighted, trigger-keyed entries that Claude can act on directly when a trigger condition is met.

---

## Data Model

**File:** `.devflow-instincts.yaml` (project root, gitignored)

```yaml
# DevFlow project instincts — auto-generated + manually curated
instincts:
  - id: churn-hooks-session-start
    trigger: "when editing hooks/session-start-learnings.sh"
    confidence: 0.55
    domain: devflow
    scope: project
    action: "File edited multiple times — review full flow before patching"
    evidence: "churn: 4 edits in 1 session"
    ts: "2026-05-26T08:00:00Z"

  - id: prefer-riverpod-over-provider
    trigger: "when choosing state management in Flutter"
    confidence: 0.8
    domain: flutter
    scope: project
    action: "Use Riverpod + hooks_riverpod, never Provider"
    evidence: "manual: observed 4x in project"
    ts: "2026-05-25T14:30:00Z"
```

### Field Reference

| Field | Type | Notes |
|---|---|---|
| `id` | kebab-case string | Unique; derived from trigger text or file path slug |
| `trigger` | string | "when…" condition — used for relevance matching at session start |
| `confidence` | float 0.0–1.0 | Auto: 0.5 (churn), 0.6 (migrated), 0.75 (manual) |
| `domain` | string | Inferred from file extension/path or explicit (flutter, react, devflow, …) |
| `scope` | `project` | Always `project` in v1; global promotion deferred |
| `action` | string | Imperative sentence — what Claude should do when trigger fires |
| `evidence` | string | Human-readable provenance string |
| `ts` | ISO-8601 | Creation or last-update timestamp |

---

## Dependencies

- `jq` — existing requirement, still needed for observe/state files
- `yq` — new requirement for YAML read/write in shell scripts
- Guard pattern (same as `jq`): `command -v yq >/dev/null 2>&1 || exit 0`

---

## Components

### 1. `hooks/session-start-learnings.sh` — rewritten

**Responsibilities:**
1. Guard on `jq` + `yq`
2. **Auto-migrate** (one-time): if `.devflow-instincts.yaml` absent but `.devflow-learnings.jsonl` exists:
   - Convert each JSONL entry to an instinct stub:
     - `churn_file` → `confidence: 0.5`, trigger from file path, action from note
     - `lesson` / `quirk` / `warning` → trigger = `"when editing <file>"` if `file` field present, else `"when working on this project"`; action = `note` field
   - Write `.devflow-instincts.yaml`
   - Rename old file to `.devflow-learnings.jsonl.migrated`
3. Read instincts via `yq`, sort by `confidence` descending
4. Filter: show only `confidence ≥ 0.4`; max 6 entries
5. Emit priority `INFO` message:

```
🧠 Project instincts (confidence ≥ 0.4):
• [0.8 flutter] when choosing state management → Use Riverpod + hooks_riverpod, never Provider
• [0.55 devflow] when editing session-start-learnings.sh → review full flow before patching
```

---

### 2. `hooks/stop-learn-distill.sh` — updated

**Responsibilities:**
1. Same churn detection (≥4 edits per file in session window, `tail -n 200` of observe log)
2. For each churned file → upsert instinct in `.devflow-instincts.yaml`:
   - **Existing id**: bump `confidence` by +0.05 (cap 0.95), update `evidence` count, update `ts`
   - **New id**: append stub with `confidence: 0.5`
3. Id derivation: file path → lowercase, non-alphanumeric → `-`, deduplicated prefix `churn-`
4. Domain inference: file extension (`.dart` → flutter, `.ts`/`.tsx` → typescript, `.py` → python, `.sh` → shell, path contains `devflow` → devflow, else `general`)
5. Ensure `.devflow-instincts.yaml` and `.devflow-learnings.jsonl.migrated` are gitignored

---

### 3. `skills/devflow-learn/SKILL.md` — updated

Sub-commands updated to operate on `.devflow-instincts.yaml` via `yq`:

| Sub-command | Behaviour |
|---|---|
| `log` | Collect `trigger`, `action`, `domain`, `confidence` (default 0.75) → write instinct with `source: manual` |
| `search <query>` | `yq` filter across `trigger` + `action` + `domain` fields; case-insensitive substring match |
| `list` | All instincts sorted by `confidence` desc; format: `[conf domain] trigger → action` |
| `prune` | Remove instincts with `confidence < 0.3`; report removed/remaining counts |
| `boost <id>` | *(new)* Bump named instinct confidence by +0.1 (cap 0.95); confirm result |

---

## Migration Flow

```
Session start, first run:
  .devflow-learnings.jsonl exists?
  YES → convert entries → write .devflow-instincts.yaml
        → rename old file to .devflow-learnings.jsonl.migrated
  NO  → nothing to migrate
```

Migration confidence mapping:

| Old type | New confidence | Rationale |
|---|---|---|
| `churn_file` | 0.5 | Auto-detected, uncertain |
| `quirk` | 0.6 | Manually noted, moderate signal |
| `lesson` | 0.65 | Actionable finding |
| `warning` | 0.7 | Known fragile area — higher weight |

---

## Out of Scope (v1)

- Global instinct promotion (cross-project tracking)
- Confidence decay over time
- Instinct merging / deduplication by semantic similarity
- Any Python tooling

---

## File I/O Summary

| File | Reader | Writer |
|---|---|---|
| `.devflow-instincts.yaml` | `session-start-learnings.sh`, `devflow-learn` skill | `stop-learn-distill.sh`, `devflow-learn` skill |
| `.devflow-learnings.jsonl` | `session-start-learnings.sh` (migration only) | *(no new writes)* |
| `.devflow-learnings.jsonl.migrated` | — | `session-start-learnings.sh` (rename) |
| `.devflow-state.json` | both hooks | — |
| `.devflow-observe.jsonl` | `stop-learn-distill.sh` | — |
