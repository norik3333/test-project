#!/bin/bash
# boulder-update.sh - Boulder State更新ヘルパー
#
# 使い方:
#   bash .claude/hooks/boulder-update.sh plan "OMC機能導入"
#   bash .claude/hooks/boulder-update.sh stage "implement"
#   bash .claude/hooks/boulder-update.sh progress 60
#   bash .claude/hooks/boulder-update.sh blocked "テスト失敗"
#   bash .claude/hooks/boulder-update.sh blocked ""          # ブロッカー解除
#   bash .claude/hooks/boulder-update.sh task-add "タスク名"
#   bash .claude/hooks/boulder-update.sh task-done "タスク名"
#
# 依存: jq (fallback: node)

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BOULDER="${PROJECT_DIR}/.souga/state/boulder.json"
mkdir -p "${PROJECT_DIR}/.souga/state"

ACTION="$1"
VALUE="$2"
TIMESTAMP="$(date +%Y-%m-%dT%H:%M:%S)"

# 初期boulder.jsonがなければ作成
if [ ! -f "$BOULDER" ]; then
  echo '{"currentPlan":"","stage":"","progress":0,"blockedOn":"","tasks":[],"compactionCount":0}' > "$BOULDER"
fi

# jq が使えない場合は node にフォールバック
if ! command -v jq &>/dev/null; then
  node - "$BOULDER" "$ACTION" "$VALUE" "$TIMESTAMP" <<'EOF'
const [,, file, action, value, ts] = process.argv;
const fs = require('fs');
const b = JSON.parse(fs.readFileSync(file, 'utf8'));
if (action === 'plan')       { b.currentPlan = value; b.stage = 'plan'; b.progress = 0; }
else if (action === 'stage')    { b.stage = value; }
else if (action === 'progress') { b.progress = parseInt(value, 10); }
else if (action === 'blocked')  { b.blockedOn = value; }
else if (action === 'task-add') { b.tasks.push({ subject: value, status: 'pending' }); }
else if (action === 'task-done'){ const t = b.tasks.find(t => t.subject === value); if (t) t.status = 'completed'; }
else if (action === 'clear')    { const cc = b.compactionCount || 0; Object.assign(b, { currentPlan:'', stage:'', progress:0, blockedOn:'', tasks:[], compactionCount: cc }); }
else { process.stderr.write('Unknown action: ' + action + '\n'); process.exit(1); }
b.timestamp = ts;
fs.writeFileSync(file, JSON.stringify(b, null, 2));
console.log('Boulder updated: ' + action + ' = ' + value);
EOF
  exit $?
fi

# jq による更新
case "$ACTION" in
  plan)
    jq --arg v "$VALUE" --arg ts "$TIMESTAMP" \
      '.currentPlan = $v | .stage = "plan" | .progress = 0 | .timestamp = $ts' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  stage)
    jq --arg v "$VALUE" --arg ts "$TIMESTAMP" \
      '.stage = $v | .timestamp = $ts' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  progress)
    jq --argjson v "$VALUE" --arg ts "$TIMESTAMP" \
      '.progress = $v | .timestamp = $ts' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  blocked)
    jq --arg v "$VALUE" --arg ts "$TIMESTAMP" \
      '.blockedOn = $v | .timestamp = $ts' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  task-add)
    jq --arg v "$VALUE" --arg ts "$TIMESTAMP" \
      '.tasks += [{"subject": $v, "status": "pending"}] | .timestamp = $ts' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  task-done)
    jq --arg v "$VALUE" --arg ts "$TIMESTAMP" \
      '(.tasks[] | select(.subject == $v) | .status) = "completed" | .timestamp = $ts' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  clear)
    jq --arg ts "$TIMESTAMP" \
      '{currentPlan:"", stage:"", progress:0, blockedOn:"", tasks:[], compactionCount: (.compactionCount // 0), timestamp: $ts}' \
      "$BOULDER" > "${BOULDER}.tmp" && mv "${BOULDER}.tmp" "$BOULDER"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac

echo "Boulder updated: $ACTION = $VALUE"
