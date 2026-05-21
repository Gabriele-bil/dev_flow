#!/usr/bin/env bash
# pre-config-protect.sh
# PreToolUse hook for Claude Code: blocks modifications to linter/formatter/analyzer
# config files to prevent weakening rules instead of fixing code.
#
# Triggered by: Write, Edit, MultiEdit tools
# Input (stdin): JSON { "session_id": "...", "tool_use": { "id": "...", "name": "...", "input": { "file_path": "..." } } }
# Block output:  { "decision": "block", "reason": "..." }  → stdout, exit 0
# Allow output:  (silent) → exit 0

set -euo pipefail

# Require jq — if not available, allow silently (never block for missing tooling)
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Read all stdin
INPUT="$(cat 2>/dev/null || true)"

# If stdin is empty or not parseable, allow silently
if [[ -z "$INPUT" ]]; then
  exit 0
fi

# Extract file_path; on any jq error allow silently
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_use.input.file_path // empty' 2>/dev/null || true)"

if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" == "null" ]]; then
  exit 0
fi

BASENAME="$(basename "$FILE_PATH")"

# ── Protected file patterns ────────────────────────────────────────────────────
#
# Flutter adapter
#   analysis_options.yaml     — analyzer / linter config
#   (pubspec.yaml is intentionally NOT protected)
#
# Angular adapter
#   eslint.config.js / .mjs / .cjs
#   .eslintrc  .eslintrc.js  .eslintrc.json  .eslintrc.yaml  .eslintrc.yml
#   tsconfig.json  tsconfig.*.json
#
# Common (all adapters)
#   .editorconfig
#   biome.json
#   prettier.config.js  .prettierrc  .prettierrc.json
# ──────────────────────────────────────────────────────────────────────────────

is_protected() {
  local name="$1"

  # Flutter
  [[ "$name" == "analysis_options.yaml" ]] && return 0

  # Angular — eslint flat config
  [[ "$name" == "eslint.config.js"  ]] && return 0
  [[ "$name" == "eslint.config.mjs" ]] && return 0
  [[ "$name" == "eslint.config.cjs" ]] && return 0

  # Angular — legacy eslintrc (any extension)
  echo "$name" | grep -qE '^\.eslintrc' && return 0

  # Angular — tsconfig*.json
  echo "$name" | grep -qE '^tsconfig.*\.json$' && return 0

  # Common
  [[ "$name" == ".editorconfig"       ]] && return 0
  [[ "$name" == "biome.json"          ]] && return 0
  [[ "$name" == "prettier.config.js"  ]] && return 0
  [[ "$name" == ".prettierrc"         ]] && return 0
  [[ "$name" == ".prettierrc.json"    ]] && return 0

  return 1
}

if is_protected "$BASENAME"; then
  REASON="Config file protected: ${BASENAME}

DevFlow blocks modifications to linter/formatter/analyzer config files.
Fix the code to satisfy the rules instead of weakening them.

To override: rename the file temporarily or ask the user to edit manually."

  printf '%s' "$(jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}')"
  exit 0
fi

exit 0
