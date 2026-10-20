#!/usr/bin/env bash
# PreToolUse hook on Edit|Write|MultiEdit|NotebookEdit. The gate files cannot be
# changed through the edit tools; an owner-approved change goes through Bash
# with the GATE_OWNER_OK prefix, which is logged.
source "$(dirname "$0")/lib.sh"

path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
grep -qE "$GATE_FILES" <<<"$path" || exit 0

gate_log BLOCKED gate-files "$path"
echo "Blocked by rule gate — $path holds the gates themselves." >&2
echo "Only if the owner told you to in this conversation, make the change with Bash prefixed with:" >&2
echo "  GATE_OWNER_OK=\"<the owner's exact words>\" <command>" >&2
exit 2
