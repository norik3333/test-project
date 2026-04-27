#!/bin/bash
# save-state-snapshot.sh - PreToolUseで呼ばれ、作業状態スナップショットを保存
#
# compaction前の状態退避として機能する。PostCompactで復元注入に使用。
# 毎回のツール呼び出し時に軽量に更新し、常に最新の状態を維持する。
#
# 出力先: .souga/state/snapshot.json

INPUT=$(cat)

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_DIR="${PROJECT_DIR}/.souga/state"
SNAPSHOT="${STATE_DIR}/snapshot.json"

mkdir -p "$STATE_DIR"

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
BRANCH=$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null || echo "unknown")

# 最新セッションファイルを特定
LATEST_SESSION=""
SESSION_DIR="${PROJECT_DIR}/.claude/sessions"
if [ -d "$SESSION_DIR" ]; then
  LATEST_SESSION=$(cd "$SESSION_DIR" && ls -t *.md 2>/dev/null | head -1 || echo "")
fi

# タスク一覧（TodoWriteの状態）は Claude 内部なので取得不可
# 代わりにgit diffの概要を保存
DIRTY_FILES=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | head -20 | tr '\n' ',' | sed 's/,$//')
UNTRACKED=$(cd "$PROJECT_DIR" && git ls-files --others --exclude-standard 2>/dev/null | head -10 | tr '\n' ',' | sed 's/,$//')

# スナップショット書き出し
python3 -c "
import json, sys

snapshot = {
    'timestamp': '$TIMESTAMP',
    'branch': '$BRANCH',
    'latest_session': '$LATEST_SESSION',
    'dirty_files': '$DIRTY_FILES',
    'untracked_files': '$UNTRACKED',
    'tool_event': 'PreToolUse'
}

with open('$SNAPSHOT', 'w') as f:
    json.dump(snapshot, f, indent=2, ensure_ascii=False)
" 2>/dev/null

exit 0
