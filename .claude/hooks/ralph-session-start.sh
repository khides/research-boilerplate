#!/usr/bin/env bash
# Ralph Session Start Hook
# Injects CLAUDE_SESSION_ID into CLAUDE_ENV_FILE so subsequent Bash calls can use it.
set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

input="$(cat)"

session_id="$(echo "$input" | jq -r '.session_id // ""')"

if [[ -n "$session_id" ]] && [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "export CLAUDE_SESSION_ID='${session_id}'" >> "$CLAUDE_ENV_FILE"
fi
