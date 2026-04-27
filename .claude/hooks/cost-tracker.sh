#!/bin/bash
# cost-tracker.sh - ツール呼び出しコスト追跡
#
# PostToolUse フックとして登録し、ツール使用回数をセッション別にログ記録する。
# Anthropic usage API 未公開のため、ツール呼び出し回数をコストプロキシとして利用。
#
# Usage:
#   (PostToolUse hook) stdin から JSON を受け取り自動ログ
#   bash cost-tracker.sh summary    # 月次サマリー表示

# Respect souga profile (skip if cost-tracker is disabled for current profile)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/souga-profile.sh" ]; then
  source "$SCRIPT_DIR/souga-profile.sh" 2>/dev/null
  if type souga_should_run &>/dev/null && [ "${1:-hook}" = "hook" ]; then
    souga_should_run "cost-tracker" || exit 0
  fi
fi

COST_DIR="$HOME/.claude/tmp/cost"
SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
COST_LOG="$COST_DIR/$(date +%Y-%m).log"
SESSION_LOG="$COST_DIR/session-${SESSION_ID}.log"
mkdir -p "$COST_DIR"

ACTION="${1:-hook}"

case "$ACTION" in
  hook)
    # PostToolUse フックモード — stdin からツール情報を読む
    INPUT=$(cat /dev/stdin 2>/dev/null || echo '{}')
    TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null \
              || echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 \
              || echo "unknown")
    TS=$(date +%Y-%m-%dT%H:%M:%S)

    # 月次ログ
    echo "$TS session=$SESSION_ID tool=$TOOL_NAME" >> "$COST_LOG"
    # セッションログ
    echo "$TS $TOOL_NAME" >> "$SESSION_LOG"
    ;;

  summary)
    echo "=== Cost Tracker Summary ==="
    if [ -f "$COST_LOG" ]; then
      TOTAL=$(wc -l < "$COST_LOG" | tr -d ' ')
      echo "Month:         $(date +%Y-%m)"
      echo "Total calls:   $TOTAL"
      echo ""
      echo "Top tools:"
      awk '{print $NF}' "$COST_LOG" | sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  %-30s %s calls\n", $2, $1}'
    else
      echo "No data for $(date +%Y-%m)."
    fi

    if [ -f "$SESSION_LOG" ]; then
      echo ""
      echo "This session: $(wc -l < "$SESSION_LOG" | tr -d ' ') calls"
    fi
    ;;

  clean)
    # 30日以上前のセッションログを削除
    find "$COST_DIR" -name "session-*.log" -mtime +30 -delete 2>/dev/null
    echo "Old session logs cleaned."
    ;;

  *)
    echo "Usage: cost-tracker.sh [hook|summary|clean]" >&2
    exit 1
    ;;
esac
