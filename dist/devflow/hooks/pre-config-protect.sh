#!/usr/bin/env bash
# pre-config-protect.sh
# PreToolUse hook for Claude Code: blocks modifications to linter/formatter/analyzer
# config files to prevent weakening rules instead of fixing code.
#
# Triggered by: Write|Edit|MultiEdit (Claude Code), file-write tools (Antigravity CLI)
# Input: host payload, parsed by lib/payload.sh (DF_FILE)
# Block output: lib/emit.sh df_deny → stdout, exit 0
# Allow output: (silent) → exit 0
# Fail-open: missing jq or unparseable input never blocks.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/lib/payload.sh"
. "$HOOK_DIR/lib/emit.sh"

df_read_input || exit 0
FILE_PATH="$DF_FILE"
[[ -z "$FILE_PATH" ]] && exit 0

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

  df_deny "$REASON"
  exit 0
fi

exit 0
