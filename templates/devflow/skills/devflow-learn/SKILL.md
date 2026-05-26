---
name: devflow-learn
description: Manage DevFlow project instincts (.devflow-instincts.yaml). Log new instincts, search past ones, list, prune low-confidence entries, or boost a specific instinct. Use when the user asks to log a finding, search past learnings, or clean up the instincts file.
argument-hint: [log, search <query>, list, prune, boost <id>]
---

# Skill: devflow.learn

## Purpose

Read, write, and maintain `.devflow-instincts.yaml` — the project's persistent instinct store. Complements the auto-detected signals written by the `stop-learn-distill` hook.

## Core Principles

- **spec-first** — no code before `task.md` + `plan.md` approved
- **traceability** — every subtask → acceptance criterion → file(s)
- **vertical slices** — end-to-end increments, never layers
- **token-lean** — caveman-compress: drop articles/hedging/filler; keep precision

## When NOT to Use

- Pipeline step execution — use `devflow.task`, `devflow.plan`, etc. instead
- First-time project setup — use `devflow.setup` instead

## Guards

Before running any sub-command, verify:

```bash
command -v yq >/dev/null 2>&1 || echo "ERROR: yq not installed. Run: brew install yq"
```

If `yq` is missing, tell the user and stop.

## Workflow

Identify the sub-command from user message or argument, then execute it.

---

### Sub-command: log

Record a manual instinct that should inform future sessions.

**Step 1 — Collect information (if not provided)**

Ask:
1. Trigger: "When should this instinct fire?" (e.g. "when choosing a state management library")
2. Action: "What should Claude do?" (one imperative sentence)
3. Domain: file type or area (e.g. `flutter`, `typescript`, `devflow`, `general`)
4. Confidence: 0.0–1.0 (default `0.75` for manual entries)

**Step 2 — Derive id from trigger**

```bash
TRIGGER="<TRIGGER>"
ID=$(printf '%s' "$TRIGGER" | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
  | cut -c1-50 | sed 's/-$//')
```

**Step 3 — Ensure instincts file exists**

```bash
if [ ! -f .devflow-instincts.yaml ]; then
  printf '%s\n' "# DevFlow project instincts" "instincts: []" > .devflow-instincts.yaml
fi
```

**Step 4 — Write instinct**

```bash
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
yq -i ".instincts += [{\"id\": \"$ID\", \"trigger\": \"<TRIGGER>\", \"confidence\": <CONFIDENCE>, \"domain\": \"<DOMAIN>\", \"scope\": \"project\", \"action\": \"<ACTION>\", \"evidence\": \"manual\", \"ts\": \"$TS\"}]" \
  .devflow-instincts.yaml
```

Confirm: "Instinct `<ID>` logged (confidence <CONFIDENCE>)."

---

### Sub-command: search

Find instincts matching a keyword across trigger, action, and domain.

**Step 1 — Run search**

```bash
yq -r \
  '.instincts[] | select((.trigger + " " + .action + " " + (.domain // "")) | test("<QUERY>"; "i")) | "• [" + (.confidence | tostring) + " " + (.domain // "general") + "] " + .trigger + " → " + .action' \
  .devflow-instincts.yaml 2>/dev/null
```

**Step 2 — Display results**

If no output: "No instincts matching `<QUERY>`."
Otherwise show results. If >5 results, group by domain.

---

### Sub-command: list

Show all instincts, sorted by confidence descending.

```bash
yq -r \
  '.instincts // [] | sort_by(.confidence) | reverse | .[] | "• [" + (.confidence | tostring) + " " + (.domain // "general") + "] " + .trigger + " → " + .action' \
  .devflow-instincts.yaml 2>/dev/null
```

If file missing or empty: "No instincts recorded yet for this project."

---

### Sub-command: prune

Remove instincts with `confidence < 0.3`.

**Step 1 — Count before**

```bash
BEFORE=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null || echo 0)
```

**Step 2 — Filter in-place**

```bash
yq -i '.instincts = [.instincts[] | select(.confidence >= 0.3)]' .devflow-instincts.yaml
```

**Step 3 — Count after and report**

```bash
AFTER=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null || echo 0)
REMOVED=$((BEFORE - AFTER))
echo "Pruned $REMOVED instincts. $AFTER remain."
```

---

### Sub-command: boost

Manually increase an instinct's confidence by +0.1 (cap 0.95).

**Step 1 — Verify id exists**

```bash
yq -r ".instincts[] | select(.id == \"<ID>\") | .id" .devflow-instincts.yaml 2>/dev/null
```

If empty: "No instinct with id `<ID>`. Use `/devflow.learn list` to see available ids."

**Step 2 — Boost confidence**

```bash
CURRENT=$(yq -r ".instincts[] | select(.id == \"<ID>\") | .confidence" .devflow-instincts.yaml)
NEW=$(awk "BEGIN {v=$CURRENT+0.1; if(v>0.95) v=0.95; printf \"%.2f\", v}")
yq -i "(.instincts[] | select(.id == \"<ID>\") | .confidence) = $NEW" .devflow-instincts.yaml
```

Confirm: "Instinct `<ID>` confidence: `$CURRENT` → `$NEW`."

---

## I/O Reference

| | |
|---|---|
| Reads | `.devflow-instincts.yaml` |
| Writes | `.devflow-instincts.yaml` |
| Related | `stop-learn-distill` hook (auto-detects churn), `session-start-learnings` hook (injects instincts) |
