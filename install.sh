#!/usr/bin/env bash
# Install the starter kit into the repository you are standing in.
#
# Never overwrites: an existing file is reported and skipped, so running this
# twice is safe and adopting the kit into a live project cannot clobber work.
#
#   /path/to/kit/install.sh --name "My Project" --repo "owner/my-project"
#   /path/to/kit/install.sh --print-board-help
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
NAME=""; REPO=""; OWNER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --repo) REPO="$2"; OWNER="${REPO%%/*}"; shift 2 ;;
    --print-board-help) cat <<'HELP'
Fetching the project board identifiers
──────────────────────────────────────
The board's own id, plus the field and option ids the scripts need:

  gh api graphql -f query='
    query($owner:String!, $number:Int!){
      user(login:$owner){ projectV2(number:$number){
        id
        fields(first:30){ nodes{
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }}
      }}
    }' -F owner=YOUR_GITHUB_LOGIN -F number=1

Copy the project `id` into PROJECT_ID, then each field's `id` and the option
ids you care about (Todo, and your Area and Priority values) into the matching
placeholders in CLAUDE.md and scripts/check-reminders.py.
HELP
      exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -d .git ]] || { echo "run this from the root of a git repository" >&2; exit 1; }
[[ -n "$NAME" ]] || { echo "--name is required" >&2; exit 1; }

copied=0; skipped=0

install_file() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    echo "  skip     $dst (already exists)"
    skipped=$((skipped + 1))
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  # Substitute only the values we were given; the rest stay visible as
  # {{PLACEHOLDERS}} so nothing silently ships half-configured.
  sed -i "s|{{PROJECT_NAME}}|$NAME|g; s|{{TODAY}}|$(date +%Y-%m-%d)|g" "$dst"
  [[ -n "$REPO"  ]] && sed -i "s|{{REPO}}|$REPO|g" "$dst"
  [[ -n "$OWNER" ]] && sed -i "s|{{OWNER}}|$OWNER|g" "$dst"
  echo "  copied   $dst"
  copied=$((copied + 1))
}

echo "Installing the starter kit into $(pwd)"
echo

while IFS= read -r rel; do
  [[ "$rel" == ".gitignore.append" ]] && continue
  install_file "$KIT/template/$rel" "$rel"
done < <(cd "$KIT/template" && find . -type f -printf '%P\n' | sort)

chmod +x .githooks/pre-commit scripts/*.sh scripts/*.py 2>/dev/null || true

# .gitignore is appended to, never replaced — the project's own rules matter
# more than ours.
if [[ -f .gitignore ]] && grep -q "must NEVER be tracked" .gitignore; then
  echo "  skip     .gitignore (never-track block already present)"
else
  cat "$KIT/template/.gitignore.append" >> .gitignore
  echo "  appended .gitignore (never-track block)"
fi

# Tracked hooks, so a fresh clone gets the guardrail instead of relying on
# someone remembering to reinstall it.
git config core.hooksPath .githooks
echo "  set      core.hooksPath = .githooks"

cat <<EOF

$copied file(s) copied, $skipped skipped.

Next, by hand:
  1. Fill the {{PLACEHOLDERS}} in CLAUDE.md — grep for '{{' to find them all.
     For the board ids:  $0 --print-board-help
  2. Delete the sections that do not apply. A rules file nobody trusts is worse
     than a short one.
  3. Point scripts/deploy.sh and scripts/verify-pages.mjs at how this project
     actually builds and runs. deploy.sh refuses to run until you do.
  4. Add the real never-track paths to .githooks/pre-commit and .gitignore.
  5. Read docs/why.md in the kit — it explains what each guardrail is for.

Verify the hook works before trusting it:
  touch .env && git add -f .env && git commit -m test   # must be refused
  git reset HEAD .env && rm .env
EOF
