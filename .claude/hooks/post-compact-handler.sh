#!/bin/bash
# post-compact-handler.sh - PostCompact hook
#
# コンパクション完了後に発火。
# 1. コンテキスト使用量をログに記録
# 2. Orchestra状態を更新
# 3. PreToolUseで保存したスナップショットを復元注入（コンテキスト継続性の確保）

INPUT=$(cat)

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

# ログ記録
LOG_DIR="${PROJECT_DIR}/.ai/logs"
mkdir -p "$LOG_DIR"
echo "[$TIMESTAMP] PostCompact: context compacted" >> "$LOG_DIR/compactions.log"

# Orchestra状態ディレクトリが存在する場合、コンテキスト情報を更新
_TMPDIR="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
ORCHESTRA_DIR=$(ls -d "${_TMPDIR}/souga-orchestra"/*/  2>/dev/null | head -1)
if [ -n "$ORCHESTRA_DIR" ] && [ -d "${ORCHESTRA_DIR}context" ]; then
  echo "{\"event\":\"compacted\",\"timestamp\":\"$TIMESTAMP\"}" >> "${ORCHESTRA_DIR}context/compactions.jsonl"
fi

# スナップショット復元注入
SNAPSHOT="${PROJECT_DIR}/.souga/state/snapshot.json"
if [ -f "$SNAPSHOT" ]; then
  SNAP_TIME=$(python3 -c "import json; print(json.load(open('$SNAPSHOT'))['timestamp'])" 2>/dev/null || echo "unknown")
  SNAP_BRANCH=$(python3 -c "import json; print(json.load(open('$SNAPSHOT'))['branch'])" 2>/dev/null || echo "unknown")
  SNAP_SESSION=$(python3 -c "import json; print(json.load(open('$SNAPSHOT'))['latest_session'])" 2>/dev/null || echo "")
  SNAP_DIRTY=$(python3 -c "import json; print(json.load(open('$SNAPSHOT'))['dirty_files'])" 2>/dev/null || echo "")

  cat << EOF
[CONTEXT RESTORED] Compaction直前の作業状態:
  時刻: ${SNAP_TIME}
  ブランチ: ${SNAP_BRANCH}
  最新セッション: ${SNAP_SESSION}
  変更中ファイル: ${SNAP_DIRTY:-なし}
  → セッションファイルを読んで前回の作業を確認してください: .claude/sessions/${SNAP_SESSION}
EOF
else
  echo "[CONTEXT RESTORED] スナップショットなし。/souga-resume でセッション復元を推奨。"
fi

# Boulder State復元注入（計画の永続化）
BOULDER="${PROJECT_DIR}/.souga/state/boulder.json"
if [ -f "$BOULDER" ]; then
  PLAN=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('currentPlan',''))" 2>/dev/null || echo "")
  STAGE=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('stage',''))" 2>/dev/null || echo "")
  PROGRESS=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('progress',0))" 2>/dev/null || echo "0")
  BLOCKED=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('blockedOn',''))" 2>/dev/null || echo "")
  COMPACTIONS=$(python3 -c "import json; print(json.load(open('$BOULDER')).get('compactionCount',0))" 2>/dev/null || echo "0")
  TASKS_SUMMARY=$(python3 -c "
import json
b = json.load(open('$BOULDER'))
tasks = b.get('tasks', [])
if tasks:
    for t in tasks[:10]:
        print(f\"  [{t.get('status','?')}] {t.get('subject','')}\")
else:
    print('  (タスクなし)')
" 2>/dev/null || echo "  (タスクなし)")

  if [ -n "$PLAN" ]; then
    cat << BEOF

[BOULDER STATE] 計画がコンテキストリセットを生き残りました (compaction #${COMPACTIONS}):
  計画: ${PLAN}
  フェーズ: ${STAGE}
  進捗: ${PROGRESS}%
  ブロッカー: ${BLOCKED:-なし}
  タスク:
${TASKS_SUMMARY}
  → この計画を継続してください。boulder.jsonを更新しながら進めてください。
  → 計画更新コマンド: python3 -c "import json; b=json.load(open('.souga/state/boulder.json')); b['stage']='新フェーズ'; b['progress']=50; json.dump(b,open('.souga/state/boulder.json','w'),indent=2)"
BEOF
  fi
fi

exit 0
