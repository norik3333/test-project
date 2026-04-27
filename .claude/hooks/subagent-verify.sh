#!/bin/bash
# subagent-verify.sh - SubagentStop hook
#
# サブエージェント終了時に発火。成果物の品質を検証する。
# 1. サブエージェントが変更したファイルにTypeScriptエラーがないか
# 2. テストが通るか（変更がtests/に関連する場合）
# 3. 結果をコンテキストに注入

INPUT=$(cat)

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

# 変更されたファイルを検出
CHANGED_TS=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | grep -E '\.(ts|tsx)$' | head -10)
CHANGED_TEST=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | grep -E '(test|spec)\.(ts|tsx|js)$' | head -5)

ISSUES=""

# TypeScript型チェック（変更ファイルがある場合のみ）
if [ -n "$CHANGED_TS" ]; then
  TSC_OUTPUT=$(cd "$PROJECT_DIR" && npx tsc --noEmit 2>&1 | head -20)
  TSC_EXIT=$?
  if [ $TSC_EXIT -ne 0 ]; then
    ISSUES="${ISSUES}
[TYPE ERROR] サブエージェントの変更にTypeScriptエラーがあります:
$(echo "$TSC_OUTPUT" | head -10)"
  fi
fi

# テスト実行（テストファイルが変更された場合のみ）
if [ -n "$CHANGED_TEST" ]; then
  TEST_OUTPUT=$(cd "$PROJECT_DIR" && npx vitest run --reporter=verbose 2>&1 | tail -15)
  TEST_EXIT=$?
  if [ $TEST_EXIT -ne 0 ]; then
    ISSUES="${ISSUES}
[TEST FAILURE] サブエージェントの変更後にテストが失敗しています:
$(echo "$TEST_OUTPUT" | tail -10)"
  fi
fi

# 結果出力
if [ -n "$ISSUES" ]; then
  cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[SUBAGENT DELIVERABLE CHECK] 成果物に問題が見つかりました
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${ISSUES}

→ サブエージェントの成果物を修正してから次に進んでください。
EOF
fi

exit 0
