# Instinct Learning System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `.devflow-learnings.jsonl` free-form entries with structured YAML instincts (`trigger`, `action`, `confidence`, `domain`) read/written by shell hooks and the `devflow-learn` skill.

**Architecture:** `.devflow-instincts.yaml` is the single source of truth; `session-start-learnings.sh` auto-migrates old JSONL on first run then injects instincts into context; `stop-learn-distill.sh` upserts churn-detected instinct stubs via `yq`; the `devflow-learn` skill exposes manual CRUD over the same file.

**Tech Stack:** bash, `jq` (existing), `yq` v4 mikefarah (new), YAML

---

## File Map

| Action | Path |
|---|---|
| Modify (rewrite tests) | `templates/devflow/scripts/test-learning-hooks.sh` |
| Modify (rewrite) | `templates/devflow/hooks/session-start-learnings.sh` |
| Modify (update) | `templates/devflow/hooks/stop-learn-distill.sh` |
| Modify (update) | `templates/devflow/skills/devflow-learn/SKILL.md` |
| Rebuild output | `dist/devflow/` (via `bash scripts/build-plugin.sh`) |

---

## Task 1: Rewrite test suite with instinct-format expectations

**Files:**
- Modify: `templates/devflow/scripts/test-learning-hooks.sh`

- [ ] **Step 1: Run existing tests to confirm baseline passes**

```bash
bash templates/devflow/scripts/test-learning-hooks.sh
```

Expected: all 11 tests pass (green baseline before changes).

- [ ] **Step 2: Replace test file with new instinct-aware tests**

Overwrite `templates/devflow/scripts/test-learning-hooks.sh` with:

```bash
#!/bin/bash
# test-learning-hooks.sh — TDD tests for the instinct learning system hooks.
# Usage: bash templates/devflow/scripts/test-learning-hooks.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(dirname "$SCRIPT_DIR")/hooks"
PASS=0
FAIL=0
ORIG_DIR="$PWD"
T=""

# ── helpers ──────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

assert_equals() {
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label" "file not found: $path"; fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then pass "$label"; else fail "$label" "unexpected file: $path"; fi
}

assert_contains() {
  local label="$1" path="$2" needle="$3"
  if grep -q "$needle" "$path" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' not in $path"; fi
}

assert_not_contains() {
  local label="$1" path="$2" needle="$3"
  if ! grep -q "$needle" "$path" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' found in $path (should be absent)"; fi
}

assert_str_contains() {
  local label="$1" str="$2" needle="$3"
  if echo "$str" | grep -q "$needle" 2>/dev/null; then pass "$label"; else fail "$label" "'$needle' not in output"; fi
}

assert_str_empty() {
  local label="$1" str="$2"
  if [ -z "$str" ]; then pass "$label"; else fail "$label" "expected empty, got: $str"; fi
}

assert_yaml_field() {
  # Assert a yq expression on a YAML file returns a specific value
  local label="$1" path="$2" expr="$3" want="$4"
  local got
  got=$(yq "$expr" "$path" 2>/dev/null) || got=""
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label" "got='$got' want='$want'"; fi
}

setup() {
  T=$(mktemp -d)
  cd "$T" || { echo "ERROR: cd to tmpdir failed"; exit 1; }
}

teardown() {
  local tmp="$T"
  cd "$ORIG_DIR"
  rm -rf "$tmp"
  T=""
}

# ── Guard: yq required ────────────────────────────────────────────────────────
if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP: yq not installed — install with: brew install yq"
  exit 0
fi

# ── session-start-learnings.sh tests ─────────────────────────────────────────

echo ""
echo "session-start-learnings.sh"
echo "──────────────────────────"

# T1: no files at all → silent exit
setup
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "no files: silent" "$OUTPUT"
teardown

# T2: instincts file exists but empty → silent exit
setup
touch .devflow-instincts.yaml
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "empty instincts: silent" "$OUTPUT"
teardown

# T3: instincts below confidence threshold → silent exit
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: low-conf-thing
    trigger: "when doing something"
    confidence: 0.2
    domain: general
    scope: project
    action: "do the thing"
    evidence: "churn: 1 session"
    ts: "2026-05-26T10:00:00Z"
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_empty "below threshold (0.2): silent" "$OUTPUT"
teardown

# T4: instincts above threshold → valid JSON with priority + message
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: prefer-riverpod
    trigger: "when choosing state management"
    confidence: 0.8
    domain: flutter
    scope: project
    action: "Use Riverpod, never Provider"
    evidence: "manual"
    ts: "2026-05-26T10:00:00Z"
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_contains "instincts present: has priority field" "$OUTPUT" '"priority"'
assert_str_contains "instincts present: has message field" "$OUTPUT" '"message"'
if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
  pass "instincts present: output is valid JSON"
else
  fail "instincts present: output is valid JSON" "jq parse failed: $OUTPUT"
fi
teardown

# T5: instinct content appears in message
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: prefer-riverpod
    trigger: "when choosing state management"
    confidence: 0.8
    domain: flutter
    scope: project
    action: "Use Riverpod, never Provider"
    evidence: "manual"
    ts: "2026-05-26T10:00:00Z"
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
assert_str_contains "trigger text in output" "$OUTPUT" "state management"
assert_str_contains "action text in output" "$OUTPUT" "Riverpod"
teardown

# T6: migration — old JSONL converted to YAML, old file renamed
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"churn_file",source:"auto",feature:"auth",file:"lib/auth.dart",note:"File edited auth.dart multiple times"}' \
  > .devflow-learnings.jsonl
bash "$HOOKS_DIR/session-start-learnings.sh" > /dev/null
assert_file_exists "migration: instincts file created" ".devflow-instincts.yaml"
assert_file_exists "migration: old file renamed to .migrated" ".devflow-learnings.jsonl.migrated"
assert_file_not_exists "migration: original JSONL removed" ".devflow-learnings.jsonl"
teardown

# T7: migration — migrated instinct has correct fields
setup
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"warning",source:"manual",file:"lib/auth.dart",note:"Auth module is fragile"}' \
  > .devflow-learnings.jsonl
bash "$HOOKS_DIR/session-start-learnings.sh" > /dev/null
assert_contains "migration: trigger references file" ".devflow-instincts.yaml" "when editing"
assert_contains "migration: action from note" ".devflow-instincts.yaml" "Auth module is fragile"
assert_yaml_field "migration: warning type gets confidence 0.7" ".devflow-instincts.yaml" \
  '.instincts[0].confidence' "0.7"
teardown

# T8: migration not re-run if instincts file already exists
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - id: existing-instinct
    trigger: "when working"
    confidence: 0.9
    domain: general
    scope: project
    action: "keep going"
    evidence: "manual"
    ts: "2026-05-26T10:00:00Z"
YAML
jq -cn '{ts:"2026-05-03T10:00:00Z",type:"lesson",source:"manual",note:"Old lesson"}' \
  > .devflow-learnings.jsonl
bash "$HOOKS_DIR/session-start-learnings.sh" > /dev/null
# JSONL should NOT have been renamed — migration skipped
assert_file_exists "migration skip: JSONL still present when yaml exists" ".devflow-learnings.jsonl"
assert_yaml_field "migration skip: existing instinct untouched" ".devflow-instincts.yaml" \
  '.instincts[0].id' "existing-instinct"
teardown

# T9: max 6 instincts surfaced
setup
cat > .devflow-instincts.yaml <<'YAML'
instincts:
  - {id: a, trigger: "t1", confidence: 0.9, domain: general, scope: project, action: "a1", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: b, trigger: "t2", confidence: 0.85, domain: general, scope: project, action: "a2", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: c, trigger: "t3", confidence: 0.8, domain: general, scope: project, action: "a3", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: d, trigger: "t4", confidence: 0.75, domain: general, scope: project, action: "a4", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: e, trigger: "t5", confidence: 0.7, domain: general, scope: project, action: "a5", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: f, trigger: "t6", confidence: 0.65, domain: general, scope: project, action: "a6", evidence: "x", ts: "2026-01-01T00:00:00Z"}
  - {id: g, trigger: "t7", confidence: 0.6, domain: general, scope: project, action: "a7", evidence: "x", ts: "2026-01-01T00:00:00Z"}
YAML
OUTPUT=$(bash "$HOOKS_DIR/session-start-learnings.sh")
COUNT=$(echo "$OUTPUT" | jq -r '.message' | grep -c "^•" || echo 0)
[ "$COUNT" -le 6 ] && pass "max 6 instincts surfaced (got $COUNT)" \
                   || fail "max 6 instincts surfaced" "got $COUNT, want ≤6"
teardown

# ── stop-learn-distill.sh tests ───────────────────────────────────────────────

echo ""
echo "stop-learn-distill.sh"
echo "─────────────────────"

# T10: no observe.jsonl → passthrough, no instincts file
setup
INPUT='{"type":"assistant","message":"hello"}'
OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOKS_DIR/stop-learn-distill.sh")
assert_equals "no observe.jsonl: passthrough stdin" "$OUTPUT" "$INPUT"
assert_file_not_exists "no observe.jsonl: no instincts file" ".devflow-instincts.yaml"
teardown

# T11: below churn threshold → no instincts file created
setup
jq -cn '{ts:"2026-05-03T10:00:01Z",event:"pre",tool:"Write",file:"lib/a.dart"}' >> .devflow-observe.jsonl
jq -cn '{ts:"2026-05-03T10:00:02Z",event:"pre",tool:"Write",file:"lib/a.dart"}' >> .devflow-observe.jsonl
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_file_not_exists "below threshold: no instincts created" ".devflow-instincts.yaml"
teardown

# T12: file edited ≥4 times → instinct stub written to YAML
setup
for i in 1 2 3 4; do
  jq -cn --arg ts "2026-05-03T10:00:0${i}Z" \
    '{ts:$ts,event:"pre",tool:"Write",file:"lib/auth/auth_provider.dart"}' \
    >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_file_exists "churn ≥4: instincts file created" ".devflow-instincts.yaml"
assert_contains "churn ≥4: id contains churn prefix" ".devflow-instincts.yaml" "churn-"
assert_contains "churn ≥4: trigger mentions file" ".devflow-instincts.yaml" "auth_provider"
assert_yaml_field "churn ≥4: initial confidence is 0.5" ".devflow-instincts.yaml" \
  '.instincts[0].confidence' "0.5"
teardown

# T13: churn on .dart file → domain is flutter
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/home.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_yaml_field "dart file: domain is flutter" ".devflow-instincts.yaml" \
  '.instincts[0].domain' "flutter"
teardown

# T14: second churn of same file → confidence bumped, not duplicated
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/auth.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
COUNT=$(yq '.instincts | length' .devflow-instincts.yaml 2>/dev/null)
assert_equals "dedup: only 1 instinct (not 2)" "$COUNT" "1"
CONF=$(yq '.instincts[0].confidence' .devflow-instincts.yaml 2>/dev/null)
# Confidence should be > 0.5 (bumped from 0.5 by 0.05)
if awk "BEGIN {exit ($CONF > 0.5) ? 0 : 1}"; then
  pass "dedup: confidence bumped above 0.5 (got $CONF)"
else
  fail "dedup: confidence bumped" "got $CONF, want > 0.5"
fi
teardown

# T15: passthrough preserves stdin exactly
setup
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/x.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
INPUT='{"type":"assistant","stop_reason":"end_turn","message":"done"}'
OUTPUT=$(printf '%s' "$INPUT" | bash "$HOOKS_DIR/stop-learn-distill.sh")
assert_equals "passthrough with churn: stdin unchanged" "$OUTPUT" "$INPUT"
teardown

# T16: instincts file gitignored after first write
setup
printf '# project ignores\n' > .gitignore
for i in 1 2 3 4; do
  jq -cn '{event:"pre",tool:"Write",file:"lib/x.dart",ts:"2026-05-03T10:00:01Z"}' >> .devflow-observe.jsonl
done
echo '{}' | bash "$HOOKS_DIR/stop-learn-distill.sh" > /dev/null
assert_contains "gitignore: .devflow-instincts.yaml added" ".gitignore" ".devflow-instincts.yaml"
teardown

# ── summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

[ "$FAIL" -gt 0 ] && exit 1
exit 0
```

- [ ] **Step 3: Run new tests — expect failures**

```bash
bash templates/devflow/scripts/test-learning-hooks.sh
```

Expected: many FAILs (hooks not yet updated). Confirm at least T1–T4 (basic guards) may pass or fail depending on current behaviour — that's fine. The goal is a failing suite to drive implementation.

- [ ] **Step 4: Commit failing tests**

```bash
git add templates/devflow/scripts/test-learning-hooks.sh
git commit -m "test(learn): replace JSONL tests with instinct-format expectations"
```

---

## Task 2: Rewrite session-start-learnings.sh

**Files:**
- Modify: `templates/devflow/hooks/session-start-learnings.sh`

- [ ] **Step 1: Overwrite the hook**

```bash
cat > templates/devflow/hooks/session-start-learnings.sh << 'SCRIPT'
#!/bin/bash
# session-start-learnings.sh — SessionStart hook: inject project instincts into session context.
# Reads .devflow-instincts.yaml (auto-migrating from .devflow-learnings.jsonl if needed).
# Outputs a JSON priority message with relevant instincts; exits silently if none.

INSTINCTS_FILE=".devflow-instincts.yaml"
LEARNINGS_LOG=".devflow-learnings.jsonl"
MAX_SHOW=6
MIN_CONFIDENCE="0.4"

# Guards: jq and yq both required
if ! command -v jq >/dev/null 2>&1; then exit 0; fi
if ! command -v yq >/dev/null 2>&1; then exit 0; fi

# ── Auto-migrate from old JSONL format (one-time) ────────────────────────────
if [ ! -f "$INSTINCTS_FILE" ] && [ -f "$LEARNINGS_LOG" ] && [ -s "$LEARNINGS_LOG" ]; then
  YAML_OUT="# DevFlow project instincts — auto-migrated from .devflow-learnings.jsonl"$'\n'"instincts:"

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    TYPE=$(printf '%s' "$line" | jq -r '.type // "lesson"' 2>/dev/null) || continue
    NOTE=$(printf '%s' "$line" | jq -r '.note // ""'       2>/dev/null) || continue
    FILE=$(printf '%s' "$line" | jq -r '.file // ""'       2>/dev/null) || true
    TS=$(printf '%s'   "$line" | jq -r '.ts // ""'         2>/dev/null) || true
    [ -z "$NOTE" ] && continue

    # Trigger and id
    if [ -n "$FILE" ]; then
      TRIGGER="when editing $FILE"
      ID_SLUG=$(printf '%s' "$FILE" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
      INSTINCT_ID="churn-${ID_SLUG}"
    else
      TRIGGER="when working on this project"
      ID_SLUG=$(printf '%s' "$NOTE" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
        | cut -c1-40 | sed 's/-$//')
      INSTINCT_ID="migrated-${ID_SLUG}"
    fi

    # Confidence by type
    case "$TYPE" in
      churn_file) CONF=0.5  ;;
      quirk)      CONF=0.6  ;;
      lesson)     CONF=0.65 ;;
      warning)    CONF=0.7  ;;
      *)          CONF=0.6  ;;
    esac

    # Domain inference
    DOMAIN="general"
    case "$FILE" in *.dart)     DOMAIN="flutter"    ;; esac
    case "$FILE" in *.ts|*.tsx) DOMAIN="typescript" ;; esac
    case "$FILE" in *.py)       DOMAIN="python"     ;; esac
    case "$FILE" in *.sh)       DOMAIN="shell"      ;; esac
    case "$FILE" in *devflow*)  DOMAIN="devflow"    ;; esac

    SAFE_NOTE=$(printf '%s'    "$NOTE"    | sed 's/"/\\"/g')
    SAFE_TRIGGER=$(printf '%s' "$TRIGGER" | sed 's/"/\\"/g')
    TS_VAL="${TS:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

    YAML_OUT="${YAML_OUT}"$'\n'"  - id: ${INSTINCT_ID}"
    YAML_OUT="${YAML_OUT}"$'\n'"    trigger: \"${SAFE_TRIGGER}\""
    YAML_OUT="${YAML_OUT}"$'\n'"    confidence: ${CONF}"
    YAML_OUT="${YAML_OUT}"$'\n'"    domain: ${DOMAIN}"
    YAML_OUT="${YAML_OUT}"$'\n'"    scope: project"
    YAML_OUT="${YAML_OUT}"$'\n'"    action: \"${SAFE_NOTE}\""
    YAML_OUT="${YAML_OUT}"$'\n'"    evidence: \"migrated from ${TYPE}\""
    YAML_OUT="${YAML_OUT}"$'\n'"    ts: \"${TS_VAL}\""
  done < "$LEARNINGS_LOG"

  printf '%s\n' "$YAML_OUT" > "$INSTINCTS_FILE"
  mv "$LEARNINGS_LOG" "${LEARNINGS_LOG}.migrated" 2>/dev/null || true
fi

# Guard: no instincts file or empty
if [ ! -f "$INSTINCTS_FILE" ] || [ ! -s "$INSTINCTS_FILE" ]; then exit 0; fi

# ── Read and surface instincts ────────────────────────────────────────────────
ENTRIES=$(
  yq -r \
    ".instincts // [] | sort_by(.confidence) | reverse | map(select(.confidence >= ${MIN_CONFIDENCE})) | .[0:${MAX_SHOW}] | .[] | \"• [\" + (.confidence | tostring) + \" \" + (.domain // \"general\") + \"] \" + .trigger + \" → \" + .action" \
    "$INSTINCTS_FILE" 2>/dev/null
) || true

[ -z "$ENTRIES" ] && exit 0

jq -cn \
  --arg entries "$ENTRIES" \
  '{
    priority: "INFO",
    message: ("🧠 Project instincts (confidence ≥ 0.4):\n\n" + $entries + "\n\nUse /devflow.learn to manage instincts (log, search, list, prune, boost).")
  }'

exit 0
SCRIPT
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n templates/devflow/hooks/session-start-learnings.sh
```

Expected: no output (clean parse).

- [ ] **Step 3: Run session-start tests**

```bash
bash templates/devflow/scripts/test-learning-hooks.sh 2>&1 | grep -A1 "session-start"
```

Expected: T1–T9 pass. If any fail, fix before continuing.

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/hooks/session-start-learnings.sh
git commit -m "feat(hooks): rewrite session-start-learnings for YAML instinct format with auto-migration"
```

---

## Task 3: Update stop-learn-distill.sh

**Files:**
- Modify: `templates/devflow/hooks/stop-learn-distill.sh`

- [ ] **Step 1: Overwrite the hook**

```bash
cat > templates/devflow/hooks/stop-learn-distill.sh << 'SCRIPT'
#!/bin/bash
# stop-learn-distill.sh — Stop hook: distill churn signals into project instincts.
# Detects file churn (≥4 edits in session) and upserts instinct stubs to
# .devflow-instincts.yaml in the consumer project root.
# Passthrough: reads stdin and writes it back to stdout unchanged.

RAW=$(cat)

OBSERVE_LOG=".devflow-observe.jsonl"
INSTINCTS_FILE=".devflow-instincts.yaml"
CHURN_THRESHOLD=4
WINDOW_LINES=200

# Guards: jq and yq both required
if ! command -v jq >/dev/null 2>&1; then printf '%s' "$RAW"; exit 0; fi
if ! command -v yq >/dev/null 2>&1; then  printf '%s' "$RAW"; exit 0; fi

# Guard: nothing to analyse
if [ ! -f "$OBSERVE_LOG" ] || [ ! -s "$OBSERVE_LOG" ]; then
  printf '%s' "$RAW"
  exit 0
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ") || true

# ── Detect churn: files written/edited ≥ CHURN_THRESHOLD times ───────────────
CHURNED_FILES=$(
  tail -n "$WINDOW_LINES" "$OBSERVE_LOG" 2>/dev/null \
  | jq -r 'select(.event=="pre" and (.tool=="Write" or .tool=="Edit" or .tool=="MultiEdit") and (.file != null and .file != "")) | .file' 2>/dev/null \
  | sort | uniq -c | awk -v thr="$CHURN_THRESHOLD" '$1 >= thr { print $2 }'
) || true

if [ -z "$CHURNED_FILES" ]; then
  printf '%s' "$RAW"
  exit 0
fi

# ── Ensure instincts file exists ──────────────────────────────────────────────
if [ ! -f "$INSTINCTS_FILE" ]; then
  printf '%s\n' "# DevFlow project instincts" "instincts: []" > "$INSTINCTS_FILE"
fi

# ── Upsert instinct for each churned file ─────────────────────────────────────
while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue

  # Derive kebab-case id
  ID_SLUG=$(printf '%s' "$filepath" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
  INSTINCT_ID="churn-${ID_SLUG}"

  # Domain inference from file extension / path
  DOMAIN="general"
  case "$filepath" in *.dart)     DOMAIN="flutter"    ;; esac
  case "$filepath" in *.ts|*.tsx) DOMAIN="typescript" ;; esac
  case "$filepath" in *.py)       DOMAIN="python"     ;; esac
  case "$filepath" in *.sh)       DOMAIN="shell"      ;; esac
  case "$filepath" in *devflow*)  DOMAIN="devflow"    ;; esac

  TRIGGER="when editing $filepath"
  ACTION="File edited multiple times — review full flow before patching"

  # Check if instinct already exists
  EXISTING_CONF=$(yq -r \
    ".instincts // [] | .[] | select(.id == \"$INSTINCT_ID\") | .confidence" \
    "$INSTINCTS_FILE" 2>/dev/null | head -1) || true

  if [ -n "$EXISTING_CONF" ] && [ "$EXISTING_CONF" != "null" ]; then
    # Bump confidence by 0.05, cap at 0.95
    NEW_CONF=$(awk "BEGIN {v=$EXISTING_CONF+0.05; if(v>0.95) v=0.95; printf \"%.2f\", v}")
    yq -i \
      "(.instincts[] | select(.id == \"$INSTINCT_ID\") | .confidence) = $NEW_CONF |
       (.instincts[] | select(.id == \"$INSTINCT_ID\") | .ts) = \"$TS\"" \
      "$INSTINCTS_FILE" 2>/dev/null || true
  else
    # Append new instinct stub
    yq -i \
      ".instincts += [{\"id\": \"$INSTINCT_ID\", \"trigger\": \"$TRIGGER\", \"confidence\": 0.5, \"domain\": \"$DOMAIN\", \"scope\": \"project\", \"action\": \"$ACTION\", \"evidence\": \"churn: 1 session\", \"ts\": \"$TS\"}]" \
      "$INSTINCTS_FILE" 2>/dev/null || true
  fi

done <<< "$CHURNED_FILES"

# ── Ensure gitignore entries ──────────────────────────────────────────────────
if [ -f ".gitignore" ]; then
  if ! grep -qF ".devflow-instincts.yaml" .gitignore 2>/dev/null; then
    printf '\n# devflow instincts\n.devflow-instincts.yaml\n.devflow-learnings.jsonl.migrated\n' \
      >> .gitignore 2>/dev/null || true
  fi
fi

printf '%s' "$RAW"
exit 0
SCRIPT
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n templates/devflow/hooks/stop-learn-distill.sh
```

Expected: no output.

- [ ] **Step 3: Run full test suite**

```bash
bash templates/devflow/scripts/test-learning-hooks.sh
```

Expected: all 16 tests pass. If T14 (confidence bump) fails, check `awk` float arithmetic output format on the system (`%.2f` vs `%f`).

- [ ] **Step 4: Commit**

```bash
git add templates/devflow/hooks/stop-learn-distill.sh
git commit -m "feat(hooks): update stop-learn-distill to upsert YAML instincts via yq"
```

---

## Task 4: Update devflow-learn/SKILL.md

**Files:**
- Modify: `templates/devflow/skills/devflow-learn/SKILL.md`

- [ ] **Step 1: Overwrite SKILL.md**

```bash
cat > templates/devflow/skills/devflow-learn/SKILL.md << 'MD'
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
MD
```

- [ ] **Step 2: Validate SKILL.md**

```bash
bash templates/devflow/scripts/validate-skills.sh 2>&1 | grep -E "devflow-learn|ERROR|PASS|FAIL"
```

Expected: `devflow-learn` passes validation (frontmatter, required sections present).

- [ ] **Step 3: Commit**

```bash
git add templates/devflow/skills/devflow-learn/SKILL.md
git commit -m "feat(skill): update devflow-learn for YAML instinct format (log/search/list/prune/boost)"
```

---

## Task 5: Rebuild dist/ and final validation

**Files:**
- Rebuild: `dist/devflow/` (generated)

- [ ] **Step 1: Run full test suite one final time**

```bash
bash templates/devflow/scripts/test-learning-hooks.sh
```

Expected: 16/16 pass. Fix any remaining failures before proceeding.

- [ ] **Step 2: Validate all skills**

```bash
bash templates/devflow/scripts/validate-skills.sh
```

Expected: all skills pass validation. Fix any failures.

- [ ] **Step 3: Rebuild dist/**

```bash
bash scripts/build-plugin.sh
```

Expected: completes without errors, `dist/devflow/` updated.

- [ ] **Step 4: Verify dist hook files updated**

```bash
grep -l "instincts" dist/devflow/hooks/*.sh
```

Expected: both `session-start-learnings.sh` and `stop-learn-distill.sh` listed.

- [ ] **Step 5: Commit rebuilt dist**

```bash
git add dist/
git commit -m "build: rebuild dist after instinct learning system upgrade"
```
