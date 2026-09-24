---
name: devflow-learn
description: Manage local and team instincts (.devflow-instincts.yaml, .devflow-instincts.shared.yaml) — log, search, list, prune, boost, or promote instincts to team store and REGISTRY.md. Use when user asks to log a finding, search learnings, manage instincts, or promote team patterns.
argument-hint: [log, search <query>, list, prune, boost <id>, promote <id>]
---

# Skill: devflow.learn

## Purpose

Read, write, and maintain persistent instincts across local and team stores:
- **Local instincts** (`.devflow-instincts.yaml`, gitignored): machine-specific learnings and auto-detected churn signals.
- **Shared team instincts** (`.devflow-instincts.shared.yaml`, committed): shared architectural gotchas and conventions for the whole team.
- **Conventions registry** (`REGISTRY.md`): human-readable architectural patterns and reusable components.

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
command -v jq >/dev/null 2>&1 || echo "ERROR: jq not installed. Run: brew install jq"
```

If `yq` or `jq` is missing, tell the user and stop.

## Workflow

Identify the sub-command from user message or argument, then execute it.

---

### Sub-command: log

Record a manual instinct in `.devflow-instincts.yaml` (local store).

#### Step 1 — Collect information (if not provided)

Ask:
1. Trigger: "When should this instinct fire?" (e.g. "when choosing a state management library")
2. Action: "What should Claude do?" (one imperative sentence)
3. Domain: file type or area (e.g. `flutter`, `typescript`, `devflow`, `general`)
4. Confidence: 0.0–1.0 (default `0.75` for manual entries)

#### Step 2 — Derive id from trigger

```bash
TRIGGER="<TRIGGER>"
ID=$(printf '%s' "$TRIGGER" | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
  | cut -c1-50 | sed 's/-$//')
```

#### Step 3 — Ensure local instincts file exists

```bash
if [ ! -f .devflow-instincts.yaml ]; then
  printf '%s\n' "# DevFlow project instincts (local)" "instincts: []" > .devflow-instincts.yaml
fi
```

#### Step 4 — Write instinct

```bash
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
yq -i ".instincts += [{\"id\": \"$ID\", \"trigger\": \"<TRIGGER>\", \"confidence\": <CONFIDENCE>, \"domain\": \"<DOMAIN>\", \"scope\": \"local\", \"action\": \"<ACTION>\", \"evidence\": \"manual\", \"ts\": \"$TS\"}]" \
  .devflow-instincts.yaml
```

Confirm: "Instinct `<ID>` logged locally (confidence `<CONFIDENCE>`)."

---

### Sub-command: search

Find instincts matching a keyword across trigger, action, and domain in both shared and local stores.

#### Step 1 — Run search

```bash
for f in .devflow-instincts.shared.yaml .devflow-instincts.yaml; do
  [ -f "$f" ] || continue
  SCOPE="🏠 local"
  [ "$f" = ".devflow-instincts.shared.yaml" ] && SCOPE="👥 team"
  yq -r \
    ".instincts[] | select((.trigger + \" \" + .action + \" \" + (.domain // \"\")) | test(\"<QUERY>\"; \"i\")) | (if .contested then \"⚠ \" else \"• \" end) + \"[\" + (.confidence | tostring) + \" \" + (.domain // \"general\") + \" $SCOPE] \" + .trigger + \" → \" + .action" \
    "$f" 2>/dev/null
done
```

#### Step 2 — Display results

If no output: "No instincts matching `<QUERY>`."
Otherwise show results. If >5 results, group by domain.

---

### Sub-command: list

Show all instincts (shared team + local), sorted by confidence descending.

```bash
SHARED_JSON=$(yq -o=json '.instincts // [] | map(.scope = "team")' .devflow-instincts.shared.yaml 2>/dev/null || echo "[]")
LOCAL_JSON=$(yq -o=json '.instincts // [] | map(.scope = "local")' .devflow-instincts.yaml 2>/dev/null || echo "[]")

jq -r --argjson shared "$SHARED_JSON" --argjson local "$LOCAL_JSON" '
  ($shared + $local)
  | group_by(.id) | map(.[0])
  | sort_by(.confidence) | reverse
  | .[]
  | (if .contested then "⚠ " else "• " end)
    + "[" + (.confidence | tostring) + " " + (.domain // "general")
    + (if .scope == "team" then " 👥 team" else " 🏠 local" end)
    + "] " + .trigger + " → " + .action
    + (if .scope == "local" and .confidence >= 0.85 then " (⭐ eligible: /devflow.learn promote " + .id + ")" else "" end)
' 2>/dev/null
```

If both files missing or empty: "No instincts recorded yet for this project."

`⚠` marks a **contested** instinct (churn signal followed by revert/reset; confidence decayed automatically). Re-verify before boosting or promoting.

---

### Sub-command: promote

Promote a high-confidence local instinct to `.devflow-instincts.shared.yaml` (committed) and optionally `REGISTRY.md`.

#### Step 1 — Verify local instinct exists

```bash
ENTRY=$(yq -o=json ".instincts[] | select(.id == \"<ID>\")" .devflow-instincts.yaml 2>/dev/null)
```

If empty: "No local instinct with id `<ID>`. Use `/devflow.learn list`."

#### Step 2 — Verify confidence threshold

```bash
CONF=$(echo "$ENTRY" | jq -r '.confidence // 0')
```

If confidence < 0.85 and `--force` not supplied: warn user that recommended threshold is ≥ 0.85 (tested across ≥5 sessions). Confirm before proceeding.

#### Step 3 — Ensure shared file exists

```bash
if [ ! -f .devflow-instincts.shared.yaml ]; then
  printf '%s\n' "# DevFlow shared team instincts (committed to git)" "instincts: []" > .devflow-instincts.shared.yaml
fi
```

#### Step 4 — Move to shared instincts

```bash
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROMOTED_ENTRY=$(echo "$ENTRY" | jq --arg ts "$TS" '.scope = "team" | .promoted_at = $ts')
yq -i ".instincts = ([.instincts[] | select(.id != \"<ID>\")] + [$PROMOTED_ENTRY])" .devflow-instincts.shared.yaml
yq -i ".instincts = [.instincts[] | select(.id != \"<ID>\")]" .devflow-instincts.yaml
```

#### Step 5 — Sync to REGISTRY.md (if --registry or confidence ≥ 0.85)

If `REGISTRY.md` or `registry.md` exists and user provided `--registry` or confirmed:
Append entry under `## Conventions & Patterns`:
```markdown
### Pattern: <TRIGGER>
- **Domain**: `<DOMAIN>` | **Confidence**: `<CONFIDENCE>`
- **Action**: `<ACTION>`
- **Source**: Promoted instinct `<ID>`
```

Confirm: "✅ Promoted instinct `<ID>` to `.devflow-instincts.shared.yaml` (scope: team). Commit this file to git."

---

### Sub-command: prune

Remove local instincts with `confidence < 0.3` (shared team instincts are protected).

```bash
BEFORE=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null || echo 0)
yq -i '.instincts = [.instincts[] | select(.confidence >= 0.3)]' .devflow-instincts.yaml
AFTER=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null || echo 0)
echo "Pruned $((BEFORE - AFTER)) local instincts. $AFTER remain."
```

---

### Sub-command: boost

Manually increase an instinct's confidence by +0.1 (cap 0.95).

```bash
TARGET=".devflow-instincts.yaml"
if ! yq -e ".instincts[] | select(.id == \"<ID>\")" "$TARGET" >/dev/null 2>&1; then
  TARGET=".devflow-instincts.shared.yaml"
fi
CURRENT=$(yq -r ".instincts[] | select(.id == \"<ID>\") | .confidence" "$TARGET")
NEW=$(awk "BEGIN {v=$CURRENT+0.1; if(v>0.95) v=0.95; printf \"%.2f\", v}")
yq -i "(.instincts[] | select(.id == \"<ID>\") | .confidence) = $NEW" "$TARGET"
echo "Instinct <ID> confidence: $CURRENT → $NEW ($TARGET)."
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
| --- | --- | --- |
| Promoting low-confidence or unverified local instincts | Pollutes team shared context with premature rules | Require confidence ≥ 0.85 and multi-session validation |
| Git-ignoring `.devflow-instincts.shared.yaml` | Team loses architectural gotchas discovered in earlier sessions | Keep shared file tracked in git; only local file is ignored |
| Never pruning stale local instincts | Stale instincts mislead future sessions | Run `prune` periodically after major refactors |
| Logging external docs or tutorials as instincts | Bloats prompt context with non-codebase knowledge | Only log codebase-specific behaviors observed during sessions |

## I/O Reference

| | |
| --- | --- |
| Reads | `.devflow-instincts.yaml`, `.devflow-instincts.shared.yaml`, `REGISTRY.md` |
| Writes | `.devflow-instincts.yaml`, `.devflow-instincts.shared.yaml`, `REGISTRY.md` |
| Related | `stop-learn-distill` hook (auto-detects churn), `session-start-learnings` hook (injects instincts) |
