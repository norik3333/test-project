#!/bin/bash
# Post-Tool Verifier — ツール実行結果の検証
# Inspired by oh-my-claudecode's post-tool-verifier
# Triggers: PostToolUse hook
#
# Validates that tool executions produced expected results
# and warns about potential issues.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null || echo "")
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // 0' 2>/dev/null || echo "0")

# Skip tools that don't need verification
case "$TOOL_NAME" in
  Read|Glob|Grep|TaskCreate|TaskUpdate|TaskGet)
    exit 0
    ;;
esac

WARNINGS=""

# Check for common error patterns in Bash output
if [[ "$TOOL_NAME" == "Bash" ]]; then
  # Detect permission errors
  if echo "$TOOL_OUTPUT" | grep -qi "permission denied"; then
    WARNINGS="${WARNINGS}⚠ Permission denied detected. Check file permissions.\n"
  fi

  # Detect out of memory
  if echo "$TOOL_OUTPUT" | grep -qi "out of memory\|ENOMEM\|heap out of memory"; then
    WARNINGS="${WARNINGS}⚠ Memory issue detected. Consider reducing scope or using streaming.\n"
  fi

  # Detect network errors
  if echo "$TOOL_OUTPUT" | grep -qi "ECONNREFUSED\|ETIMEDOUT\|ENOTFOUND\|network error"; then
    WARNINGS="${WARNINGS}⚠ Network error detected. Check connectivity.\n"
  fi

  # Detect disk space issues
  if echo "$TOOL_OUTPUT" | grep -qi "no space left\|ENOSPC\|disk full"; then
    WARNINGS="${WARNINGS}⚠ Disk space issue. Free up space before continuing.\n"
  fi

  # Detect rate limiting
  if echo "$TOOL_OUTPUT" | grep -qi "rate limit\|429\|too many requests"; then
    WARNINGS="${WARNINGS}⚠ Rate limit hit. Wait before retrying.\n"
  fi
fi

# Check for Write/Edit tool issues
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
  # Check if output indicates failure
  if echo "$TOOL_OUTPUT" | grep -qi "error\|failed\|not found\|does not exist"; then
    WARNINGS="${WARNINGS}⚠ File operation may have failed. Verify the change.\n"
  fi
fi

# Output warnings if any
if [[ -n "$WARNINGS" ]]; then
  echo -e "Post-Tool Verifier:\n${WARNINGS}"
fi
