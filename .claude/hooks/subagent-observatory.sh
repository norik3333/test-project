#!/bin/bash
# Subagent Observatory — Agent実行の可視化とパフォーマンス追跡
# Inspired by oh-my-claudecode's Agent Observatory
# Triggers: SubagentStop hook

set -euo pipefail

HOOK_EVENT="${CLAUDE_HOOK_EVENT:-SubagentStop}"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
# Windows (Git Bash) / macOS / Linux 互換のtmpdir
_TMPDIR="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}"
OBSERVATORY_DIR="${_TMPDIR}/souga-observatory/${SESSION_ID}"

mkdir -p "$OBSERVATORY_DIR"

# Read hook input from stdin
INPUT=$(cat)

AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"' 2>/dev/null || echo "unknown")
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null || echo "unknown")
DURATION_RAW=$(echo "$INPUT" | jq -r '.duration_ms // 0' 2>/dev/null || echo "0")
TOOL_COUNT_RAW=$(echo "$INPUT" | jq -r '.tool_count // 0' 2>/dev/null || echo "0")
STATUS=$(echo "$INPUT" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")

# Ensure numeric values for --argjson (guard against empty or non-numeric input)
# Note: avoid pipe+grep with pipefail — use [[ ]] test instead
[[ "$DURATION_RAW" =~ ^[0-9]+$ ]] && DURATION="$DURATION_RAW" || DURATION=0
[[ "$TOOL_COUNT_RAW" =~ ^[0-9]+$ ]] && TOOL_COUNT="$TOOL_COUNT_RAW" || TOOL_COUNT=0

# Record agent execution
RECORD_FILE="${OBSERVATORY_DIR}/agents.jsonl"

RECORD=$(jq -c -n \
  --arg name "$AGENT_NAME" \
  --arg id "$AGENT_ID" \
  --arg status "$STATUS" \
  --argjson duration "${DURATION:-0}" \
  --argjson tools "${TOOL_COUNT:-0}" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{name: $name, id: $id, status: $status, duration_ms: $duration, tool_count: $tools, timestamp: $timestamp}')

echo "$RECORD" >> "$RECORD_FILE"

# Generate summary statistics (ensure numeric for --argjson)
TOTAL_RAW=$(wc -l < "$RECORD_FILE" | tr -d ' ')
SUCCESS_RAW=$(grep -c '"status":"completed"' "$RECORD_FILE" || true)
[[ "$TOTAL_RAW" =~ ^[0-9]+$ ]] && TOTAL="$TOTAL_RAW" || TOTAL=0
[[ "$SUCCESS_RAW" =~ ^[0-9]+$ ]] && SUCCESS="$SUCCESS_RAW" || SUCCESS=0

# Write summary file for Monitor pane to read
SUMMARY_FILE="${OBSERVATORY_DIR}/summary.json"
jq -n \
  --argjson total "$TOTAL" \
  --argjson success "$SUCCESS" \
  --arg last_agent "$AGENT_NAME" \
  --arg last_status "$STATUS" \
  --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{total_agents: $total, successful: $success, last_agent: $last_agent, last_status: $last_status, updated: $updated}' > "$SUMMARY_FILE"

# Output for Claude's context (brief)
echo "Observatory: ${AGENT_NAME} ${STATUS} (${DURATION}ms, ${TOOL_COUNT} tools) | Total: ${TOTAL} agents, ${SUCCESS} success"
