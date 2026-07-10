#!/bin/bash
# devflow Tier 2 eval runner: deterministic, CI-safe, no tokens spent.
# Checks:
#   1. Description collision: pairwise similarity between core skill descriptions.
#      >=75% overlap -> error, >=50% -> warning.
#   2. Trigger routing: for each evals/cases/<skill>.json, positive prompts must
#      rank their own skill within top_k by keyword overlap against every core
#      skill's description; negative prompts must rank their declared "owner"
#      skill above the skill under test.
# This is a lexical approximation (bag-of-words overlap), not semantic
# judgment -- see evals/README.md. Usage: bash scripts/run-evals.sh
#
# Bash-3.2 compatible on purpose (macOS ships no newer bash by default) --
# no associative arrays, only parallel indexed arrays.
#
# Exit 0: no errors (warnings allowed)
# Exit 1: one or more collisions >=75% or trigger/routing failures

set -uo pipefail
export LC_ALL=C  # force '.' decimal separator and byte-order sort regardless of user locale

command -v jq >/dev/null 2>&1 || { echo "run-evals.sh requires jq"; exit 1; }

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$PLUGIN_ROOT/skills"
CASES_DIR="$PLUGIN_ROOT/evals/cases"

ERRORS=0
WARNINGS=0

STOPWORDS='^(the|and|or|to|of|in|on|for|with|this|that|these|those|is|are|be|been|use|used|using|when|user|users|asks|run|runs|running|do|does|did|my|me|at|as|before|after|into|from|via|not|no|if|then|so|but|you|your|we|our|us|can|will|would|should|its|it|by|an|a)$'

# Minimal suffix stripping so "implement/implements", "fail/fails/failing",
# "recover/recovers", "dispatch/dispatches", "merge/merging" etc. match across
# prompt and description -- a real gap found by an early run of this script.
stem_token() {
  local w="$1" len=${#1}
  if [[ $len -ge 6 && "$w" == *ing ]]; then
    w="${w%ing}"
  elif [[ $len -ge 6 && "$w" == *ies ]]; then
    w="${w%ies}y"
  elif [[ $len -ge 5 && ( "$w" == *ches || "$w" == *shes || "$w" == *xes || "$w" == *ses || "$w" == *zes ) ]]; then
    w="${w%es}"
  elif [[ $len -ge 5 && "$w" == *s && "$w" != *ss ]]; then
    w="${w%s}"
  elif [[ $len -ge 6 && "$w" == *ed ]]; then
    w="${w%ed}"
  fi
  printf '%s' "$w"
}

normalize() {
  local tok
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' ' ' | tr -s ' ' '\n' | \
    grep -vE "$STOPWORDS" | grep -vE '^.{1,2}$' | \
    while IFS= read -r tok; do stem_token "$tok"; echo; done | \
    grep -vE '^.{0,2}$' | sort -u
}

# ── Build description token sets + invocation mode for all core skills ───
# (parallel indexed arrays -- bash 3.2 on macOS has no associative arrays)
SKILL_NAMES=()
DESC_FILES=()
NL_INVOCABLE=()  # "true" unless the skill sets disable-model-invocation: true

desc_file_for() {
  # $1 = skill name; echoes the matching tmpfile path, or nothing
  local i
  for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do
    if [[ "${SKILL_NAMES[$i]}" == "$1" ]]; then
      echo "${DESC_FILES[$i]}"
      return 0
    fi
  done
}

is_nl_invocable() {
  # $1 = skill name; prints "true"/"false" (default true if unknown)
  local i
  for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do
    if [[ "${SKILL_NAMES[$i]}" == "$1" ]]; then
      echo "${NL_INVOCABLE[$i]}"
      return 0
    fi
  done
  echo "true"
}

while IFS= read -r f; do
  NAME=$(basename "$(dirname "$f")")
  DESC=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$f")
  [[ -z "$DESC" ]] && continue
  DISABLE_FLAG=$(awk '/^disable-model-invocation:/{print $2; exit}' "$f")
  TMPFILE=$(mktemp)
  normalize "$DESC" > "$TMPFILE"
  SKILL_NAMES+=("$NAME")
  DESC_FILES+=("$TMPFILE")
  if [[ "$DISABLE_FLAG" == "true" ]]; then
    NL_INVOCABLE+=("false")
  else
    NL_INVOCABLE+=("true")
  fi
done < <(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" | sort)

echo "Loaded ${#SKILL_NAMES[@]} core skill descriptions."
echo ""

# ── 1. Collision check: pairwise Jaccard similarity ───────────────────────
echo "== Description collision check =="
for ((i = 0; i < ${#SKILL_NAMES[@]}; i++)); do
  for ((j = i + 1; j < ${#SKILL_NAMES[@]}; j++)); do
    A="${SKILL_NAMES[$i]}"
    B="${SKILL_NAMES[$j]}"
    FA="${DESC_FILES[$i]}"
    FB="${DESC_FILES[$j]}"
    INTER=$(comm -12 "$FA" "$FB" | wc -l | tr -d ' ')
    UNION=$(cat "$FA" "$FB" | sort -u | wc -l | tr -d ' ')
    [[ "$UNION" -eq 0 ]] && continue
    SIM=$(awk -v i="$INTER" -v u="$UNION" 'BEGIN { printf "%.2f", (i/u)*100 }')
    SIM_INT=${SIM%.*}
    if [[ $SIM_INT -ge 75 ]]; then
      echo "  ERROR: $A <-> $B description similarity ${SIM}% (>=75%)"
      ERRORS=$((ERRORS + 1))
    elif [[ $SIM_INT -ge 50 ]]; then
      echo "  WARN:  $A <-> $B description similarity ${SIM}% (>=50%)"
      WARNINGS=$((WARNINGS + 1))
    fi
  done
done
echo ""

# ── 2. Trigger routing check ──────────────────────────────────────────────
echo "== Trigger routing check =="

score_against_all() {
  # $1 = tmpfile of normalized prompt tokens
  # writes "skill<TAB>score" lines to stdout, one per skill
  local PROMPT_FILE="$1"
  local NAME DESC_FILE OVERLAP
  for NAME in "${SKILL_NAMES[@]}"; do
    DESC_FILE=$(desc_file_for "$NAME")
    OVERLAP=$(comm -12 "$PROMPT_FILE" "$DESC_FILE" | wc -l | tr -d ' ')
    printf '%s\t%s\n' "$NAME" "$OVERLAP"
  done
}

rank_of() {
  # $1 = ranked list (name<TAB>score, sorted desc by score then name asc)
  # $2 = target skill name; prints 1-based rank
  awk -F'\t' -v t="$2" '{ if ($1==t) { print NR; exit } }' <<< "$1"
}

TOTAL_POS=0
PASSED_POS=0

for CASE_FILE in "$CASES_DIR"/*.json; do
  [[ -f "$CASE_FILE" ]] || continue
  SKILL=$(jq -r '.skill_name' "$CASE_FILE")

  if [[ "$(is_nl_invocable "$SKILL")" != "true" ]]; then
    echo "  SKIP:  [$SKILL] disable-model-invocation: true -- only reachable via explicit command, NL trigger routing does not apply"
    continue
  fi

  POS_COUNT=$(jq '.trigger.positive | length' "$CASE_FILE")
  for ((k = 0; k < POS_COUNT; k++)); do
    PROMPT=$(jq -r ".trigger.positive[$k].prompt" "$CASE_FILE")
    TOP_K=$(jq -r ".trigger.positive[$k].top_k // 3" "$CASE_FILE")
    PTMP=$(mktemp)
    normalize "$PROMPT" > "$PTMP"
    RANKED=$(score_against_all "$PTMP" | sort -t"$(printf '\t')" -k2,2nr -k1,1)
    RANK=$(rank_of "$RANKED" "$SKILL")
    rm -f "$PTMP"
    TOTAL_POS=$((TOTAL_POS + 1))
    if [[ -z "$RANK" ]]; then
      echo "  ERROR: [$SKILL] positive prompt scored zero overlap with every skill: \"$PROMPT\""
      ERRORS=$((ERRORS + 1))
      continue
    fi
    if [[ "$RANK" -le "$TOP_K" ]]; then
      PASSED_POS=$((PASSED_POS + 1))
    else
      echo "  ERROR: [$SKILL] positive prompt ranked #$RANK (want top-$TOP_K): \"$PROMPT\""
      ERRORS=$((ERRORS + 1))
    fi
  done

  NEG_COUNT=$(jq '.trigger.negative | length' "$CASE_FILE")
  for ((k = 0; k < NEG_COUNT; k++)); do
    PROMPT=$(jq -r ".trigger.negative[$k].prompt" "$CASE_FILE")
    OWNER=$(jq -r ".trigger.negative[$k].owner" "$CASE_FILE")
    if [[ "$(is_nl_invocable "$OWNER")" != "true" ]]; then
      echo "  SKIP:  [$SKILL] owner '$OWNER' has disable-model-invocation: true -- routing comparison not meaningful: \"$PROMPT\""
      continue
    fi
    PTMP=$(mktemp)
    normalize "$PROMPT" > "$PTMP"
    RANKED=$(score_against_all "$PTMP" | sort -t"$(printf '\t')" -k2,2nr -k1,1)
    SKILL_RANK=$(rank_of "$RANKED" "$SKILL")
    OWNER_RANK=$(rank_of "$RANKED" "$OWNER")
    rm -f "$PTMP"
    if [[ -z "$OWNER_RANK" || -z "$SKILL_RANK" ]]; then
      echo "  WARN:  [$SKILL] negative prompt matched nothing, cannot assert owner outranks: \"$PROMPT\""
      WARNINGS=$((WARNINGS + 1))
      continue
    fi
    if [[ "$OWNER_RANK" -lt "$SKILL_RANK" ]]; then
      : # owner correctly outranks this skill
    else
      echo "  ERROR: [$SKILL] negative prompt ranks owner ($OWNER, #$OWNER_RANK) behind self (#$SKILL_RANK): \"$PROMPT\""
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo ""
if [[ $TOTAL_POS -gt 0 ]]; then
  RANK1_RATE=$(awk -v p="$PASSED_POS" -v t="$TOTAL_POS" 'BEGIN { printf "%.0f", (p/t)*100 }')
  echo "Trigger top-k pass rate: $PASSED_POS/$TOTAL_POS ($RANK1_RATE%)"
fi
echo "Results: $ERRORS error(s), $WARNINGS warning(s)"

# cleanup description token tmpfiles
for FILE in "${DESC_FILES[@]}"; do
  rm -f "$FILE"
done

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
