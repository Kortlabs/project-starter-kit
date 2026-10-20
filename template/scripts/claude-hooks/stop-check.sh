#!/usr/bin/env bash
# Stop hook. A turn cannot end while uncommitted source changes break a rule, so
# "done" is never claimed over a known violation. The second stop in a row
# passes (stop_hook_active) to avoid a loop; the violation is still logged.
source "$(dirname "$0")/lib.sh"

active=$(jq -r '.stop_hook_active // false')
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -f scripts/check-rules.mjs ] || exit 0

mapfile -t files < <(git status --porcelain -uall -- "${SRC_DIRS[@]}" | sed -E 's/^.. //; s/.* -> //')
[ ${#files[@]} -eq 0 ] && exit 0

if out=$(node scripts/check-rules.mjs --unstaged "${files[@]}" 2>&1); then exit 0; fi

gate_log BLOCKED stop-check "$(grep -c '^  [a-z]' <<<"$out") violation(s) in uncommitted changes"
[ "$active" = "true" ] && exit 0
echo "$out" >&2
echo "Uncommitted changes break the rules above. Fix them before ending the turn." >&2
exit 2
