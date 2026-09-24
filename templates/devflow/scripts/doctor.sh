#!/usr/bin/env bash
# doctor.sh — DevFlow Environment, MCP, and Pipeline Health Diagnostic
# Usage: bash templates/devflow/scripts/doctor.sh [--json] [--fix]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(pwd)"

JSON_MODE=false
FIX_MODE=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --fix) FIX_MODE=true ;;
  esac
done

# ── Color / formatting helpers (disabled in JSON mode) ──────────────────────
if [[ "$JSON_MODE" == false && -t 1 ]]; then
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_GREEN="\033[32m"
  C_YELLOW="\033[33m"
  C_RED="\033[31m"
  C_CYAN="\033[36m"
  C_GRAY="\033[90m"
else
  C_RESET=""
  C_BOLD=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_CYAN=""
  C_GRAY=""
fi

# Track issues
CRITICAL_ERRORS=0
WARNINGS=0
REMEDIATIONS=()

# ── Section 1: Detect Client Environment ─────────────────────────────────────
DETECTED_CLIENT="Unknown"
MCP_CONFIG_PATHS=()

# Check Antigravity / Gemini IDE
if [[ -n "${ANTIGRAVITY_APP_DIR:-}" || -d "$HOME/.gemini/antigravity-ide" || -d "$WORKSPACE_ROOT/.agents" ]]; then
  DETECTED_CLIENT="Antigravity / Gemini IDE"
fi
[[ -f "$HOME/.gemini/config/mcp_config.json" ]] && MCP_CONFIG_PATHS+=("$HOME/.gemini/config/mcp_config.json")
[[ -f "$WORKSPACE_ROOT/.agents/mcp_config.json" ]] && MCP_CONFIG_PATHS+=("$WORKSPACE_ROOT/.agents/mcp_config.json")

# Check Claude Code
if [[ -f "$WORKSPACE_ROOT/.mcp.json" || -f "$HOME/.claude.json" ]]; then
  [[ "$DETECTED_CLIENT" == "Unknown" ]] && DETECTED_CLIENT="Claude Code"
fi
[[ -f "$WORKSPACE_ROOT/.mcp.json" ]] && MCP_CONFIG_PATHS+=("$WORKSPACE_ROOT/.mcp.json")
[[ -f "$HOME/.claude.json" ]] && MCP_CONFIG_PATHS+=("$HOME/.claude.json")

# Check Cursor
if [[ -f "$WORKSPACE_ROOT/.cursor/mcp.json" || -f "$HOME/.cursor/mcp.json" ]]; then
  [[ "$DETECTED_CLIENT" == "Unknown" ]] && DETECTED_CLIENT="Cursor"
fi
[[ -f "$WORKSPACE_ROOT/.cursor/mcp.json" ]] && MCP_CONFIG_PATHS+=("$WORKSPACE_ROOT/.cursor/mcp.json")
[[ -f "$HOME/.cursor/mcp.json" ]] && MCP_CONFIG_PATHS+=("$HOME/.cursor/mcp.json")

# ── Section 2: Detect Active Adapter ─────────────────────────────────────────
CONFIG_FILE=""
if [[ -f "$WORKSPACE_ROOT/devflow/config.md" ]]; then
  CONFIG_FILE="$WORKSPACE_ROOT/devflow/config.md"
elif [[ -f "$WORKSPACE_ROOT/.devflow/config.md" ]]; then
  CONFIG_FILE="$WORKSPACE_ROOT/.devflow/config.md"
elif [[ -f "$PLUGIN_ROOT/config.md" ]]; then
  CONFIG_FILE="$PLUGIN_ROOT/config.md"
fi

DETECTED_ADAPTER="unknown"
ADAPTER_STATUS="missing"

if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
  RAW_ADAPTER=$(grep -iE '\*\*Adapter:\*\*' "$CONFIG_FILE" | head -1 | sed -E 's/.*\*\*Adapter:\*\*[[:space:]]*//' | tr -d '`* ' | tr '[:upper:]' '[:lower:]')
  if [[ -n "$RAW_ADAPTER" && "$RAW_ADAPTER" != *"[todo"* ]]; then
    DETECTED_ADAPTER="$RAW_ADAPTER"
    ADAPTER_STATUS="configured"
  fi
fi

# Fallback auto-detection if config.md is unconfigured
if [[ "$DETECTED_ADAPTER" == "unknown" ]]; then
  if [[ -f "$WORKSPACE_ROOT/pubspec.yaml" ]]; then
    DETECTED_ADAPTER="flutter"
    ADAPTER_STATUS="inferred (pubspec.yaml)"
  elif [[ -f "$WORKSPACE_ROOT/angular.json" ]] || grep -q '"@angular/' "$WORKSPACE_ROOT/package.json" 2>/dev/null; then
    DETECTED_ADAPTER="angular"
    ADAPTER_STATUS="inferred (angular.json/package.json)"
  elif [[ -f "$WORKSPACE_ROOT/next.config.js" || -f "$WORKSPACE_ROOT/next.config.mjs" || -f "$WORKSPACE_ROOT/next.config.ts" ]] || grep -q '"next"' "$WORKSPACE_ROOT/package.json" 2>/dev/null; then
    DETECTED_ADAPTER="nextjs"
    ADAPTER_STATUS="inferred (next.config/package.json)"
  elif [[ -f "$WORKSPACE_ROOT/nest-cli.json" ]] || grep -q '"@nestjs/' "$WORKSPACE_ROOT/package.json" 2>/dev/null; then
    DETECTED_ADAPTER="nestjs"
    ADAPTER_STATUS="inferred (nest-cli.json/package.json)"
  fi
fi

# ── Section 3: Inspect Configured MCP Servers ────────────────────────────────
CONFIGURED_MCPS=()
for CFG in "${MCP_CONFIG_PATHS[@]}"; do
  if [[ -f "$CFG" ]] && command -v jq >/dev/null 2>&1; then
    SERVERS=$(jq -r '(.mcpServers // {}) | keys[]' "$CFG" 2>/dev/null || true)
    while IFS= read -r s; do
      [[ -n "$s" ]] && CONFIGURED_MCPS+=("$s")
    done <<< "$SERVERS"
  fi
done

# Deduplicate configured MCPs
UNIQUE_MCPS=()
if [[ ${#CONFIGURED_MCPS[@]} -gt 0 ]]; then
  while IFS= read -r item; do
    [[ -n "$item" ]] && UNIQUE_MCPS+=("$item")
  done < <(printf '%s\n' "${CONFIGURED_MCPS[@]}" | sort -u)
fi

is_mcp_configured() {
  local target="$1"
  for m in "${UNIQUE_MCPS[@]}"; do
    if [[ "$m" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

# Baseline check
MCP_RESULTS=()
record_mcp() {
  local name="$1"
  local tier="$2"     # baseline | stack-core | conditional
  local note="$3"
  local status="MISSING"

  if is_mcp_configured "$name"; then
    status="OK"
  else
    if [[ "$tier" == "baseline" || "$tier" == "stack-core" ]]; then
      status="DEGRADED"
      WARNINGS=$((WARNINGS + 1))
      REMEDIATIONS+=("Configure MCP server '$name' ($note)")
    else
      status="OPTIONAL"
    fi
  fi
  MCP_RESULTS+=("$name|$tier|$status|$note")
}

record_mcp "context7" "baseline" "Live library/API documentation"
record_mcp "sequential-thinking" "baseline" "Multi-step reasoning & refactoring"
record_mcp "serena" "baseline" "AST / semantic code index (or other LSP index)"

case "$DETECTED_ADAPTER" in
  flutter)
    record_mcp "dart" "stack-core" "Dart symbol lookup & signatures"
    ;;
  angular)
    record_mcp "angular-cli" "stack-core" "Angular CLI best practices & devserver"
    record_mcp "playwright" "stack-core" "Runtime e2e verify & ARIA accessibility trees"
    ;;
  nextjs)
    record_mcp "next-devtools" "stack-core" "Next.js 16+ dev diagnostics & Server Actions"
    record_mcp "playwright" "stack-core" "Runtime browser verification & ARIA trees"
    ;;
  nestjs)
    record_mcp "openapi" "stack-core" "OpenAPI / Swagger spec inspection"
    ;;
esac

# Check conditional infrastructure
USES_SUPABASE=false
if grep -qiE 'supabase' "$WORKSPACE_ROOT/package.json" 2>/dev/null || grep -qiE 'supabase' "$WORKSPACE_ROOT/pubspec.yaml" 2>/dev/null; then
  USES_SUPABASE=true
  record_mcp "supabase" "conditional" "Detected Supabase dependency in project"
fi

USES_POSTGRES=false
if grep -qiE 'pg|postgres|typeorm' "$WORKSPACE_ROOT/package.json" 2>/dev/null; then
  USES_POSTGRES=true
  record_mcp "postgres" "conditional" "Detected PostgreSQL / TypeORM in project"
fi

USES_SENTRY=false
if grep -qiE 'sentry' "$WORKSPACE_ROOT/package.json" 2>/dev/null || grep -qiE 'sentry' "$WORKSPACE_ROOT/pubspec.yaml" 2>/dev/null; then
  USES_SENTRY=true
  record_mcp "sentry" "conditional" "Detected Sentry monitoring in project"
fi

# ── Section 4: Inspect CLI Toolchain ─────────────────────────────────────────
CLI_RESULTS=()
check_cli() {
  local bin="$1"
  local required="$2"
  local ver_flag="${3:---version}"

  if command -v "$bin" >/dev/null 2>&1; then
    local ver
    ver=$("$bin" $ver_flag 2>&1 | head -1 | tr -d '\r\n')
    CLI_RESULTS+=("$bin|OK|$ver")
  else
    if [[ "$required" == "true" ]]; then
      CLI_RESULTS+=("$bin|MISSING|Not found in PATH")
      CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
      REMEDIATIONS+=("Install required tool: $bin")
    else
      CLI_RESULTS+=("$bin|OPTIONAL|Not found in PATH")
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
}

check_cli "git" "true" "--version"
check_cli "gh" "false" "--version"
check_cli "jq" "true" "--version"

case "$DETECTED_ADAPTER" in
  flutter)
    check_cli "flutter" "true" "--version"
    check_cli "dart" "true" "--version"
    ;;
  angular)
    check_cli "node" "true" "-v"
    check_cli "pnpm" "false" "-v"
    check_cli "ng" "false" "version"
    ;;
  nextjs)
    check_cli "node" "true" "-v"
    check_cli "pnpm" "false" "-v"
    ;;
  nestjs)
    check_cli "node" "true" "-v"
    check_cli "npm" "true" "-v"
    check_cli "nest" "false" "--version"
    ;;
  *)
    check_cli "node" "false" "-v"
    ;;
esac

# ── Section 5: Pipeline & Repository Health ──────────────────────────────────
PIPELINE_RESULTS=()

# Git repo check
IN_GIT=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=true
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$DIRTY" -eq 0 ]]; then
    PIPELINE_RESULTS+=("Git Working Tree|OK|Clean (branch: $BRANCH)")
  else
    PIPELINE_RESULTS+=("Git Working Tree|WARN|$DIRTY uncommitted change(s) (branch: $BRANCH)")
    WARNINGS=$((WARNINGS + 1))
  fi
else
  PIPELINE_RESULTS+=("Git Repository|FAIL|Not inside a git repository")
  CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
  REMEDIATIONS+=("Initialize git repository: git init")
fi

# Pipeline State (.devflow-state.json)
STATE_FILE="$WORKSPACE_ROOT/.devflow-state.json"
if [[ -f "$STATE_FILE" ]]; then
  if command -v jq >/dev/null 2>&1 && jq empty "$STATE_FILE" >/dev/null 2>&1; then
    ACTIVE_FEAT=$(jq -r '.active_feature // empty' "$STATE_FILE")
    NEXT_STEP=$(jq -r '.next_step // empty' "$STATE_FILE")
    if [[ -n "$ACTIVE_FEAT" ]]; then
      PIPELINE_RESULTS+=("Pipeline State|OK|Feature: $ACTIVE_FEAT | Next step: ${NEXT_STEP:-none}")
    else
      PIPELINE_RESULTS+=("Pipeline State|OK|Idle (no active feature)")
    fi
  else
    PIPELINE_RESULTS+=("Pipeline State|FAIL|Corrupted JSON in .devflow-state.json")
    CRITICAL_ERRORS=$((CRITICAL_ERRORS + 1))
    REMEDIATIONS+=("Repair pipeline state with 'devflow.recovery' or reset .devflow-state.json")
    if [[ "$FIX_MODE" == true ]]; then
      echo '{"active_feature": null, "next_step": null}' > "$STATE_FILE"
      REMEDIATIONS+=("Auto-fix: Reset corrupted .devflow-state.json to valid idle state")
    fi
  fi
else
  PIPELINE_RESULTS+=("Pipeline State|OK|No active state (idle)")
fi

# Gitignore check
if [[ -f "$WORKSPACE_ROOT/.gitignore" ]]; then
  if grep -qF ".devflow-state.json" "$WORKSPACE_ROOT/.gitignore"; then
    PIPELINE_RESULTS+=("Gitignore Protection|OK|.devflow-state.json is ignored")
  else
    PIPELINE_RESULTS+=("Gitignore Protection|WARN|.devflow-state.json not in .gitignore")
    WARNINGS=$((WARNINGS + 1))
    REMEDIATIONS+=("Add .devflow-state.json to .gitignore")
    if [[ "$FIX_MODE" == true ]]; then
      echo -e "\n# devflow runtime state\n.devflow-state.json" >> "$WORKSPACE_ROOT/.gitignore"
      REMEDIATIONS+=("Auto-fix: Appended .devflow-state.json to .gitignore")
    fi
  fi
fi

# Instincts check
INSTINCTS_FILE="$WORKSPACE_ROOT/.devflow-instincts.yaml"
if [[ -f "$INSTINCTS_FILE" ]]; then
  INSTINCTS_COUNT=$(grep -E '^[[:space:]]*- id:' "$INSTINCTS_FILE" 2>/dev/null | wc -l | tr -d ' ')
  PIPELINE_RESULTS+=("Instincts Engine|OK|$INSTINCTS_COUNT recorded project instinct(s)")
else
  PIPELINE_RESULTS+=("Instincts Engine|INFO|No project instincts recorded yet")
fi

# Overall Verdict
OVERALL_STATUS="healthy"
EXIT_CODE=0
if [[ $CRITICAL_ERRORS -gt 0 ]]; then
  OVERALL_STATUS="unhealthy"
  EXIT_CODE=2
elif [[ $WARNINGS -gt 0 ]]; then
  OVERALL_STATUS="degraded"
  EXIT_CODE=1
fi

if [[ "$JSON_MODE" == true ]]; then
  export DOCTOR_STATUS="$OVERALL_STATUS"
  export DOCTOR_EXIT_CODE="$EXIT_CODE"
  export DOCTOR_CLIENT="$DETECTED_CLIENT"
  export DOCTOR_ADAPTER_NAME="$DETECTED_ADAPTER"
  export DOCTOR_ADAPTER_STATUS="$ADAPTER_STATUS"

  python3 -c '
import os, sys, json

data = {
  "status": os.environ["DOCTOR_STATUS"],
  "exit_code": int(os.environ["DOCTOR_EXIT_CODE"]),
  "client": os.environ["DOCTOR_CLIENT"],
  "adapter": {
    "name": os.environ["DOCTOR_ADAPTER_NAME"],
    "status": os.environ["DOCTOR_ADAPTER_STATUS"]
  },
  "mcp_servers": json.loads(sys.argv[1]),
  "cli_tools": json.loads(sys.argv[2]),
  "pipeline_health": json.loads(sys.argv[3]),
  "remediations": json.loads(sys.argv[4])
}
print(json.dumps(data, indent=2))
' "$(printf '%s\n' "${MCP_RESULTS[@]}" | python3 -c 'import sys, json; print(json.dumps([{"name": p[0], "tier": p[1], "status": p[2], "note": p[3]} for l in sys.stdin if l.strip() for p in [l.strip().split("|")] if len(p)>=4]))')" \
  "$(printf '%s\n' "${CLI_RESULTS[@]}" | python3 -c 'import sys, json; print(json.dumps([{"name": p[0], "status": p[1], "detail": p[2]} for l in sys.stdin if l.strip() for p in [l.strip().split("|")] if len(p)>=3]))')" \
  "$(printf '%s\n' "${PIPELINE_RESULTS[@]}" | python3 -c 'import sys, json; print(json.dumps([{"check": p[0], "status": p[1], "detail": p[2]} for l in sys.stdin if l.strip() for p in [l.strip().split("|")] if len(p)>=3]))')" \
  "$(printf '%s\n' "${REMEDIATIONS[@]}" | python3 -c 'import sys, json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"

  exit $EXIT_CODE
fi

# Human-readable terminal output
echo -e "${C_BOLD}DevFlow Doctor Diagnostic${C_RESET}"
echo -e "${C_GRAY}======================================================${C_RESET}"
echo -e "Client:  ${C_CYAN}$DETECTED_CLIENT${C_RESET}"
echo -e "Adapter: ${C_CYAN}$DETECTED_ADAPTER${C_RESET} (${ADAPTER_STATUS})"
if [[ ${#MCP_CONFIG_PATHS[@]} -gt 0 ]]; then
  echo -e "Configs: ${C_GRAY}$(IFS=', '; echo "${MCP_CONFIG_PATHS[*]}")"
fi
echo ""

# 1. MCP Servers
echo -e "${C_BOLD}1. Model Context Protocol (MCP) Baseline${C_RESET}"
for res in "${MCP_RESULTS[@]}"; do
  IFS='|' read -r name tier status note <<< "$res"
  case "$status" in
    OK)
      echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}$name${C_RESET} (${tier}) — ${C_GREEN}Configured${C_RESET}"
      ;;
    DEGRADED)
      echo -e "  ${C_YELLOW}⚠${C_RESET} ${C_BOLD}$name${C_RESET} (${tier}) — ${C_YELLOW}Absent (CLI fallback active)${C_RESET} — ${C_GRAY}$note${C_RESET}"
      ;;
    OPTIONAL)
      echo -e "  ${C_GRAY}·${C_RESET} ${C_BOLD}$name${C_RESET} (${tier}) — ${C_GRAY}Not configured (optional)${C_RESET} — ${C_GRAY}$note${C_RESET}"
      ;;
  esac
done
echo ""

# 2. CLI Toolchain
echo -e "${C_BOLD}2. CLI Toolchain${C_RESET}"
for res in "${CLI_RESULTS[@]}"; do
  IFS='|' read -r bin status detail <<< "$res"
  case "$status" in
    OK)
      echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}$bin${C_RESET} — ${C_GRAY}$detail${C_RESET}"
      ;;
    MISSING)
      echo -e "  ${C_RED}✗${C_RESET} ${C_BOLD}$bin${C_RESET} — ${C_RED}Missing required binary${C_RESET}"
      ;;
    OPTIONAL)
      echo -e "  ${C_YELLOW}⚠${C_RESET} ${C_BOLD}$bin${C_RESET} — ${C_YELLOW}Not found in PATH (optional)${C_RESET}"
      ;;
  esac
done
echo ""

# 3. Pipeline & Workspace Health
echo -e "${C_BOLD}3. Pipeline & Workspace Health${C_RESET}"
for res in "${PIPELINE_RESULTS[@]}"; do
  IFS='|' read -r check status detail <<< "$res"
  case "$status" in
    OK)
      echo -e "  ${C_GREEN}✓${C_RESET} ${C_BOLD}$check${C_RESET}: $detail"
      ;;
    WARN)
      echo -e "  ${C_YELLOW}⚠${C_RESET} ${C_BOLD}$check${C_RESET}: $detail"
      ;;
    FAIL)
      echo -e "  ${C_RED}✗${C_RESET} ${C_BOLD}$check${C_RESET}: $detail"
      ;;
    INFO)
      echo -e "  ${C_GRAY}·${C_RESET} ${C_BOLD}$check${C_RESET}: $detail"
      ;;
  esac
done
echo ""

# 4. Summary & Remediations
echo -e "${C_GRAY}──────────────────────────────────────────────────────${C_RESET}"
if [[ "$OVERALL_STATUS" == "healthy" ]]; then
  echo -e "Status: ${C_GREEN}${C_BOLD}HEALTHY${C_RESET} — All systems ready for DevFlow pipeline."
elif [[ "$OVERALL_STATUS" == "degraded" ]]; then
  echo -e "Status: ${C_YELLOW}${C_BOLD}DEGRADED${C_RESET} — Pipeline functional with graceful fallbacks ($WARNINGS warning(s))."
else
  echo -e "Status: ${C_RED}${C_BOLD}UNHEALTHY${C_RESET} — $CRITICAL_ERRORS critical issue(s) detected."
fi

if [[ ${#REMEDIATIONS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${C_BOLD}Recommended Actions:${C_RESET}"
  for rem in "${REMEDIATIONS[@]}"; do
    echo -e "  - $rem"
  done
  echo ""
  echo -e "${C_GRAY}Tip: Run 'devflow.setup --mcp' to generate or update your client MCP configuration.${C_RESET}"
fi

exit $EXIT_CODE
