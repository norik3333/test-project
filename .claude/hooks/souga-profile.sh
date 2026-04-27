#!/bin/bash
# souga-profile.sh - Shared library for hook profile management
# Source this file in other hooks to control execution based on profile.
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/souga-profile.sh"
#        souga_should_run "quality-gate" || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default profile: standard
SOUGA_PROFILE="${SOUGA_PROFILE:-standard}"

# Profile config file
PROFILE_CONFIG="$SCRIPT_DIR/profile-config.json"

# Check if a hook should run based on current profile
souga_should_run() {
  local hook_id="$1"

  # If no config file, use built-in defaults
  if [ ! -f "$PROFILE_CONFIG" ] || ! command -v jq &>/dev/null; then
    case "$SOUGA_PROFILE" in
      minimal)
        case "$hook_id" in
          session-start|session-end) return 0 ;;
          *) return 1 ;;
        esac
        ;;
      standard)
        case "$hook_id" in
          security-scan) return 1 ;;
          *) return 0 ;;
        esac
        ;;
      strict)
        return 0
        ;;
    esac
    return 0
  fi

  # Use jq to check config
  local enabled
  enabled=$(jq -r ".profiles.${SOUGA_PROFILE}.hooks.\"${hook_id}\" // true" "$PROFILE_CONFIG" 2>/dev/null)
  [ "$enabled" = "true" ]
}
