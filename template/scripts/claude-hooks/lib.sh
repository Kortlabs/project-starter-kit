# Shared by the Claude Code hooks. Every block and every owner-approved pass is
# appended to the log; the daily report counts them.
GATE_LOG="${HOME}/.claude/gate-blocks.log"

gate_log() { # <BLOCKED|ALLOWED> <rule> <subject> [owner quote]
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" \
    "$(printf '%s' "$3" | tr '\n\t' '  ' | cut -c1-200)" "${4:-}" >> "$GATE_LOG"
}

# Files that hold the gates themselves. Changing one weakens every gate, so it
# needs the owner's quoted approval like any other bypass.
GATE_FILES='(\.claude/settings(\.local)?\.json|scripts/claude-hooks/|scripts/check-rules\.mjs|scripts/check-commit-msg\.mjs|scripts/gate-audit-commit\.sh|\.githooks/|\.git/hooks/|gate-blocks\.log)'

# Source directories the Stop hook and the gate audit look at. Adapt to the
# layout: `src`, or `frontend/src backend/src`.
SRC_DIRS=(src)
