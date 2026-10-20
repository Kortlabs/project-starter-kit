#!/usr/bin/env bash
# Deploy {{PROJECT_NAME}}.
#
# The shape matters more than the commands. Three properties, each of which was
# learned by losing them:
#
#   1. Build BEFORE touching the running service. A failed build must abort
#      while production is still serving the last good version.
#   2. Reload rather than restart, so in-flight requests survive the swap.
#   3. Health-check afterwards and fail loudly. A deploy that "succeeded" and
#      left the service down is the worst outcome, because nobody looks.
#
# Adapt the marked sections; keep the structure.
#
#   scripts/deploy.sh            # build, deploy, verify, tag
#   scripts/deploy.sh --no-tag   # throwaway deploy
set -euo pipefail
cd "$(dirname "$0")/.."

TAG=1
[[ "${1:-}" == "--no-tag" ]] && TAG=0

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mDEPLOY FAILED: %s\033[0m\n' "$*" >&2; exit 1; }

# Refuse to deploy a dirty tree: whatever is running should be identifiable by
# a commit, or you cannot roll back to it.
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || fail "working tree is dirty — commit or stash first"
COMMIT=$(git rev-parse --short HEAD)

# ── 0. Review (advisory, starts now, findings printed last) ────────────────
# Every other check in this script is mechanical; this one reads the logic. A
# headless /code-review over everything since the last deploy tag, which is
# exactly what is about to ship. It starts before the build so the build absorbs
# its minutes, and the tag is pushed before the script waits for it. Advisory:
# a review finding is a judgment, and a false positive must never hold a
# hotfix. Whoever runs the deploy reads the findings and fixes or relays them.
# Skipped on a throwaway deploy, on the first deploy, and without the CLI.
PREV=$(git for-each-ref --sort=-creatordate --count=1 --format='%(refname:short)' 'refs/tags/deploy/*')
REVIEW_PID=""
if [[ "$TAG" == "1" && -n "$PREV" ]] && command -v claude >/dev/null && [[ -n "$(git log --oneline "$PREV..HEAD")" ]]; then
  log "Reviewing $PREV..HEAD in the background"
  # Unattended and read-only: print mode cannot prompt, so the tools it may use
  # are named and the editing tools refused. The 15-minute cap and the EXIT trap
  # keep a hung or orphaned review from outliving the deploy.
  timeout 900 claude -p "/code-review high $PREV..HEAD" --output-format text \
    --allowedTools 'Read,Grep,Glob,Bash(git:*)' --disallowedTools 'Edit,Write,MultiEdit,NotebookEdit' \
    </dev/null >/tmp/deploy-review.log 2>&1 &
  REVIEW_PID=$!
  trap 'kill "$REVIEW_PID" 2>/dev/null || true' EXIT
fi

# ── 1. Build ────────────────────────────────────────────────────────────────
# Nothing below this point runs if the build fails.
log "Building ($COMMIT)"
npm run build || fail "build failed — the running service was not touched"

# ── 2. Swap ─────────────────────────────────────────────────────────────────
# Process manager: prefer reload. For a static or edge deploy, this is the
# upload step instead.
log "Deploying"
# pm2 reload {{SERVICE_NAME}} || fail "reload failed"
# npx wrangler deploy || fail "wrangler deploy failed"
fail "deploy step not configured yet — edit scripts/deploy.sh"

# ── 3. Verify ───────────────────────────────────────────────────────────────
# Give the service a moment, then prove it answers. Poll rather than sleeping a
# fixed time: a slow boot is normal, a dead service is not.
log "Verifying"
HEALTH_URL="${HEALTH_URL:-http://localhost:3000/}"
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$HEALTH_URL" || echo 000)
  [[ "$code" =~ ^(200|301|302|307)$ ]] && break
  [[ $i -eq 20 ]] && fail "health check never passed (last status $code)"
  sleep 2
done
echo "health check ok ($code)"

# ── 4. Tag ──────────────────────────────────────────────────────────────────
# Every tag is a commit that passed a health check in production, which makes
# `git tag -l 'deploy/*'` a list of known-good rollback targets.
if [[ "$TAG" == "1" ]]; then
  NAME="deploy/$(date +%Y%m%d-%H%M)"
  git tag -a "$NAME" -m "Deployed $COMMIT" && git push -q origin "$NAME"
  log "Tagged $NAME"
fi

# ── 5. Review findings ──────────────────────────────────────────────────────
# Printed, never acted on by the script: the deploy is live and tagged already.
if [[ -n "$REVIEW_PID" ]]; then
  if wait "$REVIEW_PID" && [[ -s /tmp/deploy-review.log ]]; then
    log "Code review of $PREV..HEAD: $(grep -c '"file":' /tmp/deploy-review.log || true) finding(s) (advisory)"
    cat /tmp/deploy-review.log
  else
    log "Code review produced nothing usable — the deploy stands; see /tmp/deploy-review.log"
  fi
fi

log "Deployed $COMMIT"
