#!/usr/bin/env bash
# Gate audit, run in the background by .githooks/post-commit. A skip or a
# gate-ok exception in the new commit is posted to the issue it references, so
# a bypass shows up on the card the owner is already looking at. Nothing can
# verify the owner said the quoted words; this and the daily report are where
# they check.
cd "$(git rev-parse --show-toplevel)" || exit 0
source scripts/claude-hooks/lib.sh

sha=$(git rev-parse --short HEAD)
msg=$(git log -1 --format=%B)
skips=$(grep -iE '^gate:[[:space:]]*skipped' <<<"$msg")
escapes=$(git show --format= -U0 HEAD -- "${SRC_DIRS[@]}" | grep -E '^\+.*gate-ok:' | sed -E 's/^\+[[:space:]]*//')
[ -z "$skips$escapes" ] && exit 0

issue=$(grep -oE '#[0-9]+' <<<"$msg" | head -1 | tr -d '#')
[ -z "$issue" ] && exit 0

body="**Gate bypass in commit ${sha}** ($(git log -1 --format=%s))"
[ -n "$skips" ] && body+=$'\n\n'"Skipped gate:"$'\n'"$(sed 's/^/> /' <<<"$skips")"
[ -n "$escapes" ] && body+=$'\n\n'"Rule exceptions added:"$'\n'"$(sed 's/^/- `/; s/$/`/' <<<"$escapes")"
body+=$'\n\n'"Owner: if you did not approve this, say so and it gets reverted."

gh issue comment "$issue" --body "$body"
