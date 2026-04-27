#!/bin/bash
# continuation-enforcement.sh - Stop hook拡張
#
# セッション終了時に発火。以下を検証:
# 1. Boulder Stateに未完了タスクがないか
# 2. 進捗が100%未満でブロッカーなしなら警告
# 3. git上に未コミットの変更がないか
#
# 出力はClaude Codeのコンテキストに注入され、
# 未完了作業がある場合は継続を促す。

INPUT=$(cat)

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BOULDER="${PROJECT_DIR}/.souga/state/boulder.json"
WARNINGS=""

# 1. Boulder State チェック
if [ -f "$BOULDER" ]; then
  PLAN=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('currentPlan',''))" 2>/dev/null || echo "")
  PROGRESS=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('progress',0))" 2>/dev/null || echo "0")
  BLOCKED=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('blockedOn',''))" 2>/dev/null || echo "")

  PENDING_TASKS=$(python3 -c "
import json
b = json.load(open('$BOULDER'))
pending = [t for t in b.get('tasks',[]) if t.get('status') != 'completed']
for t in pending:
    print(f\"  - [{t.get('status','pending')}] {t.get('subject','')}\")
if not pending:
    print('')
" 2>/dev/null || echo "")

  if [ -n "$PLAN" ] && [ "$PROGRESS" -lt 100 ] 2>/dev/null; then
    if [ -z "$BLOCKED" ]; then
      WARNINGS="${WARNINGS}
[CONTINUATION WARNING] 計画「${PLAN}」が未完了です (進捗: ${PROGRESS}%)
  ブロッカーなし — 作業を継続してください。"
    else
      WARNINGS="${WARNINGS}
[CONTINUATION INFO] 計画「${PLAN}」が未完了です (進捗: ${PROGRESS}%)
  ブロッカー: ${BLOCKED}
  → ブロッカーがあるため一時停止は許容されます。"
    fi
  fi

  if [ -n "$PENDING_TASKS" ]; then
    WARNINGS="${WARNINGS}
[PENDING TASKS] 未完了タスク:
${PENDING_TASKS}
  → これらのタスクを完了してからセッションを終了してください。"
  fi
fi

# 2. 未コミット変更チェック
DIRTY=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(cd "$PROJECT_DIR" && git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

if [ "$DIRTY" -gt 0 ] || [ "$STAGED" -gt 0 ]; then
  WARNINGS="${WARNINGS}
[UNCOMMITTED CHANGES] ${DIRTY}個の未保存変更、${STAGED}個のステージ済み変更があります。
  → コミットするか、/souga-save でセッション状態を保存してください。"
fi

# 3. 出力
if [ -n "$WARNINGS" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "THE BOULDER NEVER STOPS — 完了確認"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$WARNINGS"
  echo ""
  echo "本当に終了しますか？未完了作業がある場合は継続を推奨します。"
fi

exit 0
