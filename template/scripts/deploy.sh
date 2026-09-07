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

log "Deployed $COMMIT"
