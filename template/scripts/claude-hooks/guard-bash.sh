#!/usr/bin/env bash
# PreToolUse hook on Bash. Refuses the commands that route around the rule gates
# or break a standing CLAUDE.md rule. Runs in every permission mode,
# bypassPermissions included: auto-accepting commands is not bypassing gates.
#
# Owner bypass: prefix the one command with GATE_OWNER_OK="<owner's exact words>".
source "$(dirname "$0")/lib.sh"

cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# A gate file counts as changed only when it is the target: after a redirect,
# the operand of a file command or in-place edit, a git checkout/restore, or
# named alongside code an interpreter runs inline (which can write anywhere).
# Merely mentioning one (a commit message, a test run, a log read) is fine.
writes_gate_file() {
  local G="$GATE_FILES" S='[^;&|]*'
  grep -qE ">>?[[:space:]]*['\"]?[^[:space:];&|]*$G" <<<"$cmd" && return 0
  grep -qE "(^|[;&|[:space:](])(rm|mv|cp|chmod|chown|truncate|ln|tee|dd|install|unlink)[[:space:]]$S$G" <<<"$cmd" && return 0
  grep -qE "(sed|perl)[[:space:]]+(-[a-zA-Z]*i|--in-place)$S$G" <<<"$cmd" && return 0
  grep -qE "git[[:space:]]+(checkout|restore|rm|mv)$S$G" <<<"$cmd" && return 0
  grep -qE "(^|[;&|[:space:](])(python3?|node|perl|ruby|bash|sh)[[:space:]]+(-[ce]([[:space:]]|$)|-([[:space:]]|$)|<<)" <<<"$cmd" && grep -qE "$G" <<<"$cmd" && return 0
  return 1
}

rule=""
if   grep -qE 'git\b.*\bcommit\b.*(--no-verify|\s-[a-zA-Z]*n[a-zA-Z]*(\s|$))' <<<"$cmd"; then rule="no-verify: git commit must run its hooks"
elif grep -qE 'git\b.*\bpush\b.*--no-verify' <<<"$cmd"; then rule="no-verify: git push must run its hooks"
elif grep -qE 'git\b.*(-c[[:space:]]*core\.hooksPath|config[^;&|]*core\.hooksPath)' <<<"$cmd"; then rule="hooks-path: redirecting git hooks disables every gate"
elif grep -qE 'git\s+add\s+(.*\s)?(-A|--all|\.)(\s|$)' <<<"$cmd"; then rule="git-add-all: stage explicit file paths only (CLAUDE.md, Git staging)"
elif grep -qE 'pm2\s+restart' <<<"$cmd"; then rule="pm2-restart: use pm2 reload; restart drops every in-flight request"
elif writes_gate_file; then
  rule="gate-files: this changes the gates themselves"
fi
[ -z "$rule" ] && exit 0

quote=$(sed -nE 's/^[[:space:]]*GATE_OWNER_OK="([^"]+)"[[:space:]].*/\1/p' <<<"$cmd")
if [ -n "$quote" ] && [ "$quote" != "1" ]; then
  gate_log ALLOWED "${rule%%:*}" "$cmd" "$quote"
  # Shown to the owner in the chat, so a bypass never passes unannounced.
  jq -n --arg m "Gate bypassed (${rule%%:*}) on the owner's words: \"$quote\"" '{systemMessage: $m}'
  exit 0
fi

gate_log BLOCKED "${rule%%:*}" "$cmd"
echo "Blocked by rule gate — $rule." >&2
echo "Only if the owner told you to in this conversation, re-run the command prefixed with:" >&2
echo "  GATE_OWNER_OK=\"<the owner's exact words>\" <command>" >&2
exit 2
