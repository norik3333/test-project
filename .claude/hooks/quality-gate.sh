#!/bin/bash
# quality-gate.sh - PostToolUse品質ゲートフック（双雅システム Phase 1）
#
# Usage: Claude Code PostToolUseフックとして使用
# Triggers after Edit/Write on .ts/.tsx files
#
# 機能:
# - TypeScript型チェック（npx tsc --noEmit）
# - ESLintチェック（利用可能な場合）
# - 3プロファイル対応: minimal / standard / strict
#
# 環境変数:
#   SOUGA_PROFILE  - minimal|standard|strict (default: standard)
#
# 終了コード:
#   0 - OK (minimal/standard: always, strict: no errors)
#   2 - strict mode errors found

# --- Configuration ---
PROFILE="${SOUGA_PROFILE:-standard}"
TIMEOUT_SEC=5

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# --- Determine target file ---
# PostToolUse hook receives tool name and file path as arguments
# $1 = tool_name (Edit or Write)
# $2 = file_path
TOOL_NAME="${1:-}"
TARGET_FILE="${2:-}"

# If no file specified, try to read from stdin (Claude Code hook protocol)
if [ -z "$TARGET_FILE" ] && [ ! -t 0 ]; then
  INPUT=$(cat)
  # Try to extract file path from JSON input
  if command -v jq &> /dev/null; then
    TARGET_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null)
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  else
    # Fallback: grep for file_path in JSON
    TARGET_FILE=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"([^"]+)"' | head -1 | sed 's/.*"\([^"]*\)"/\1/')
  fi
fi

# --- Guard: only run for Edit/Write on .ts/.tsx files ---
if [ -n "$TOOL_NAME" ]; then
  case "$TOOL_NAME" in
    Edit|Write) ;;
    *) exit 0 ;;
  esac
fi

# Check file extension
case "$TARGET_FILE" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Check file exists
if [ ! -f "$TARGET_FILE" ]; then
  exit 0
fi

# --- Profile: minimal = skip entirely ---
if [ "$PROFILE" = "minimal" ]; then
  exit 0
fi

# --- Header ---
echo -e "${CYAN}[quality-gate]${NC} ${DIM}profile=${PROFILE} file=$(basename "$TARGET_FILE")${NC}"

# --- Navigate to project root ---
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT"

# Make target file relative to project root for display
REL_FILE="${TARGET_FILE#$PROJECT_ROOT/}"

# --- Collect violations ---
VIOLATIONS=0
TSC_ERRORS=""
ESLINT_ERRORS=""

# --- 1. TypeScript type check ---
# Use tsc on the specific file with the project's tsconfig
# timeout to keep it under 5 seconds
if command -v npx &> /dev/null; then
  TSC_OUTPUT=$(timeout "${TIMEOUT_SEC}s" npx tsc --noEmit --pretty false 2>&1 || true)
  TSC_EXIT=$?

  # Filter errors related to the edited file only
  if [ -n "$TSC_OUTPUT" ]; then
    TSC_FILE_ERRORS=$(echo "$TSC_OUTPUT" | grep -F "$REL_FILE" | grep "error TS" || true)
    if [ -n "$TSC_FILE_ERRORS" ]; then
      TSC_ERROR_COUNT=$(echo "$TSC_FILE_ERRORS" | wc -l | tr -d ' ')
      VIOLATIONS=$((VIOLATIONS + TSC_ERROR_COUNT))
      TSC_ERRORS="$TSC_FILE_ERRORS"
    fi
  fi

  # Report tsc results
  if [ -n "$TSC_ERRORS" ]; then
    echo -e "${YELLOW}  tsc: ${VIOLATIONS} type error(s) in ${REL_FILE}${NC}"
    echo "$TSC_ERRORS" | head -5 | while IFS= read -r line; do
      echo -e "    ${RED}${line}${NC}"
    done
    if [ "$VIOLATIONS" -gt 5 ]; then
      echo -e "    ${DIM}... and $((VIOLATIONS - 5)) more${NC}"
    fi
  else
    echo -e "${GREEN}  tsc: OK${NC}"
  fi
else
  echo -e "${DIM}  tsc: skipped (npx not found)${NC}"
fi

# --- 2. ESLint check ---
ESLINT_VIOLATIONS=0
if command -v npx &> /dev/null && [ -f "$PROJECT_ROOT/node_modules/.bin/eslint" ] || [ -f "$PROJECT_ROOT/.eslintrc.json" ] || [ -f "$PROJECT_ROOT/.eslintrc.js" ] || [ -f "$PROJECT_ROOT/.eslintrc.cjs" ] || [ -f "$PROJECT_ROOT/eslint.config.js" ] || [ -f "$PROJECT_ROOT/eslint.config.mjs" ]; then
  ESLINT_OUTPUT=$(timeout "${TIMEOUT_SEC}s" npx eslint --no-fix --format compact "$TARGET_FILE" 2>&1 || true)
  ESLINT_EXIT=$?

  if [ $ESLINT_EXIT -ne 0 ] && [ -n "$ESLINT_OUTPUT" ]; then
    # Count error lines (compact format: file:line:col: message)
    ESLINT_FILE_ERRORS=$(echo "$ESLINT_OUTPUT" | grep -E "^.+:[0-9]+:[0-9]+:" || true)
    if [ -n "$ESLINT_FILE_ERRORS" ]; then
      ESLINT_VIOLATIONS=$(echo "$ESLINT_FILE_ERRORS" | wc -l | tr -d ' ')
      VIOLATIONS=$((VIOLATIONS + ESLINT_VIOLATIONS))
      ESLINT_ERRORS="$ESLINT_FILE_ERRORS"
    fi
  fi

  if [ -n "$ESLINT_ERRORS" ]; then
    echo -e "${YELLOW}  eslint: ${ESLINT_VIOLATIONS} issue(s) in ${REL_FILE}${NC}"
    echo "$ESLINT_ERRORS" | head -5 | while IFS= read -r line; do
      echo -e "    ${RED}${line}${NC}"
    done
    if [ "$ESLINT_VIOLATIONS" -gt 5 ]; then
      echo -e "    ${DIM}... and $((ESLINT_VIOLATIONS - 5)) more${NC}"
    fi
  else
    echo -e "${GREEN}  eslint: OK${NC}"
  fi
else
  echo -e "${DIM}  eslint: skipped (not configured)${NC}"
fi

# --- Summary ---
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${YELLOW}[quality-gate]${NC} ${VIOLATIONS} total violation(s) found"

  # strict or standard profile: block on errors (exit 2)
  if [ "$PROFILE" = "strict" ] || [ "$PROFILE" = "standard" ]; then
    echo -e "${RED}[quality-gate]${NC} BLOCKING - ${PROFILE} mode rejects ${VIOLATIONS} violation(s)"
    exit 2
  fi

  # minimal profile: warn only (exit 0)
  echo -e "${DIM}[quality-gate]${NC} ${DIM}warnings only (profile=minimal). Set SOUGA_PROFILE=standard to block.${NC}"
  exit 0
else
  echo -e "${GREEN}[quality-gate]${NC} All checks passed"
  exit 0
fi
