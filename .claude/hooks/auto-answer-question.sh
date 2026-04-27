#!/bin/bash
# auto-answer-question.sh - PreToolUse hook for AskUserQuestion
#
# 自律実行中に AskUserQuestion が呼ばれた場合、
# 自動的に「続行してください」と応答して中断を防ぐ。
#
# 対象環境:
#   SOUGA_AUTO_MODE=1 — souga-auto (Water Spider) モード
#   SOUGA_PANE_ROLE が設定済み — Orchestra Agent Team モード
#   どちらも未設定の場合はスキップ（通常のインタラクティブセッション）

# 自律実行モードの判定
AUTO_MODE=0
REASON=""

if [ "${SOUGA_AUTO_MODE}" = "1" ]; then
  AUTO_MODE=1
  REASON="souga-autoモード"
elif [ -n "${SOUGA_PANE_ROLE}" ]; then
  AUTO_MODE=1
  REASON="Orchestra ${SOUGA_PANE_ROLE}モード"
fi

# 自律実行モードでない場合はスキップ
if [ "${AUTO_MODE}" != "1" ]; then
  exit 0
fi

# stdin からJSON入力を読み取る
INPUT=$(cat)

# AskUserQuestion に対して自動応答を返す
cat << EOF
{
  "permissionDecision": "allow",
  "updatedInput": {
    "question": "自動応答: ${REASON}のため自分で判断して続行してください。質問は不要です。"
  }
}
EOF
