#!/bin/bash
# validate-typescript.sh - TypeScript検証フック
#
# Usage: Git pre-commitフックまたはClaude Codeフックとして使用
# Git Hook:   ln -s ../../.claude/hooks/validate-typescript.sh .git/hooks/pre-commit
# Claude:     { "hooks": { "beforeCommit": ".claude/hooks/validate-typescript.sh" } }
#
# 機能:
# - TypeScriptコンパイルエラーチェック
# - 型チェック（strict mode）
# - エラーがある場合はコミットを中断

set -e

echo "🔍 TypeScript validation hook running..."

# プロジェクトルートに移動
cd "$(git rev-parse --show-toplevel)"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ステージングされたTypeScriptファイルを取得
STAGED_TS_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$' || true)

if [ -z "$STAGED_TS_FILES" ]; then
  echo "✅ No TypeScript files to validate"
  exit 0
fi

echo "📝 Found $(echo "$STAGED_TS_FILES" | wc -l | tr -d ' ') TypeScript files"

# TypeScript型チェック実行
echo ""
echo "🔧 Running TypeScript compiler (tsc --noEmit)..."
echo ""

TYPECHECK_EXIT=0
if npm run typecheck 2>&1 | tee "${TMPDIR:-${TMP:-${TEMP:-/tmp}}}/typecheck.log"; then
  echo ""
  echo -e "${GREEN}✅ TypeScript validation passed - all types are correct${NC}"
  exit 0
else
  TYPECHECK_EXIT=$?
  echo ""
  echo -e "${RED}❌ TypeScript validation failed${NC}"
  echo ""
  echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${YELLOW}║               TypeScript Compilation Errors Found            ║${NC}"
  echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # エラーサマリー表示
  ERROR_COUNT=$(grep -c "error TS" "${TMPDIR:-${TMP:-${TEMP:-/tmp}}}/typecheck.log" || echo "0")
  echo -e "${RED}Total Errors: $ERROR_COUNT${NC}"
  echo ""

  # 最初の10個のエラーを表示
  echo -e "${BLUE}First errors:${NC}"
  grep "error TS" "${TMPDIR:-${TMP:-${TEMP:-/tmp}}}/typecheck.log" | head -10
  echo ""

  echo -e "${YELLOW}How to fix:${NC}"
  echo "  1. Review the errors above"
  echo "  2. Fix type errors in your TypeScript files"
  echo "  3. Run 'npm run typecheck' to verify fixes"
  echo "  4. Re-stage your files with 'git add'"
  echo ""
  echo -e "${YELLOW}To skip this check (not recommended):${NC}"
  echo "  git commit --no-verify -m \"your message\""
  echo ""

  exit 1
fi
