#!/bin/bash
# pre-compact-handler.sh - PreCompact hook
#
# コンテキストコンパクション直前に発火。
# Boulder State（計画状態）を .souga/state/boulder.json に保存する。
# PostCompactで復元注入され、計画がコンテキストリセットを生き残る。
#
# 保存内容:
#   - 現在の計画名・フェーズ・進捗率
#   - ブロッカー・未解決問題
#   - 直近の作業サマリ
#   - タスク状態（完了/進行中/未着手）

INPUT=$(cat)

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_DIR="${PROJECT_DIR}/.souga/state"
BOULDER="${STATE_DIR}/boulder.json"
SNAPSHOT="${STATE_DIR}/snapshot.json"

mkdir -p "$STATE_DIR"

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
BRANCH=$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null || echo "unknown")

# 直近のコミットメッセージ（作業コンテキスト推定）
RECENT_COMMITS=$(cd "$PROJECT_DIR" && git log --oneline -5 2>/dev/null | tr '\n' '|' | sed 's/|$//')

# 変更中ファイル
DIRTY_FILES=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | head -20 | tr '\n' ',' | sed 's/,$//')
STAGED_FILES=$(cd "$PROJECT_DIR" && git diff --cached --name-only 2>/dev/null | head -20 | tr '\n' ',' | sed 's/,$//')

# 既存のboulder.jsonがあればマージ（進捗を上書きしない）
EXISTING_PLAN=""
EXISTING_STAGE=""
EXISTING_PROGRESS=""
EXISTING_BLOCKED=""
EXISTING_TASKS=""
if [ -f "$BOULDER" ]; then
  EXISTING_PLAN=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('currentPlan',''))" 2>/dev/null || echo "")
  EXISTING_STAGE=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('stage',''))" 2>/dev/null || echo "")
  EXISTING_PROGRESS=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('progress',0))" 2>/dev/null || echo "0")
  EXISTING_BLOCKED=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('blockedOn',''))" 2>/dev/null || echo "")
  EXISTING_TASKS=$(python3 -c "import json; print(json.dumps(json.load(open('$BOULDER')).get('tasks',[])))" 2>/dev/null || echo "[]")
fi

# Boulder State書き出し
python3 -c "
import json

boulder = {
    'timestamp': '$TIMESTAMP',
    'branch': '$BRANCH',
    'currentPlan': '${EXISTING_PLAN}',
    'stage': '${EXISTING_STAGE}',
    'progress': int('${EXISTING_PROGRESS}' or '0'),
    'blockedOn': '${EXISTING_BLOCKED}',
    'recentCommits': '${RECENT_COMMITS}'.split('|') if '${RECENT_COMMITS}' else [],
    'dirtyFiles': '${DIRTY_FILES}'.split(',') if '${DIRTY_FILES}' else [],
    'stagedFiles': '${STAGED_FILES}'.split(',') if '${STAGED_FILES}' else [],
    'tasks': json.loads('${EXISTING_TASKS}' or '[]'),
    'compactionCount': 0,
    'event': 'PreCompact'
}

# インクリメント compaction count
try:
    with open('$BOULDER', 'r') as f:
        prev = json.load(f)
        boulder['compactionCount'] = prev.get('compactionCount', 0) + 1
except:
    boulder['compactionCount'] = 1

with open('$BOULDER', 'w') as f:
    json.dump(boulder, f, indent=2, ensure_ascii=False)
" 2>/dev/null

exit 0
