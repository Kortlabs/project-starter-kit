#!/usr/bin/env python3
"""Turn dated commitments in ops/reminders.yml into GitHub issues when due.

Why issues rather than a calendar: work lands on the project board, and a due
date that arrives anywhere else gets dismissed. An
issue sits in Todo until someone closes it, carries Area and Priority like
everything else, and is visible to whoever picks the work up next.

Idempotent by design — it searches for an open issue carrying the reminder's id
marker before creating one, so running nightly cannot produce duplicates. A
recurring reminder re-opens on its next cycle once the previous issue is closed.

Usage:  scripts/check-reminders.py [--dry-run]
"""
import argparse
import json
import re
import os
import subprocess
import sys
import urllib.request
from datetime import date, timedelta
from pathlib import Path

import yaml

# ── Configure for this project ───────────────────────────────────────────────
# Board field and option ids come from the GraphQL API; see README for the query.
REPO = "{{REPO}}"
OWNER = "{{OWNER}}"
PROJECT_NUMBER = "{{PROJECT_NUMBER}}"
PROJECT_ID = "{{PROJECT_ID}}"
STATUS_FIELD, TODO = "{{STATUS_FIELD}}", "{{STATUS_TODO}}"
AREA_FIELD = "{{AREA_FIELD}}"
PRIORITY_FIELD = "{{PRIORITY_FIELD}}"
AREAS = {{AREAS_MAP}}
PRIORITIES = {{PRIORITIES_MAP}}
# ─────────────────────────────────────────────────────────────────────────────
MARKER = "reminder-id:"


def sh(argv, **kw):
    return subprocess.run(argv, capture_output=True, text=True, **kw)


def next_due(r, today):
    """One-off due date, or the next occurrence of a recurring reminder."""
    if "due" in r:
        return date.fromisoformat(str(r["due"]))
    step = r["every"]
    n = int(re.match(r"(\d+)", step).group(1))
    days = n * 365 if step.endswith("y") else n
    # `from` is the last time it was DONE, so the next occurrence is one full
    # cycle later — anchoring on `from` itself would raise the reminder on the
    # very day the work was completed.
    #
    # No loop to the next future cycle on purpose: an overdue occurrence must
    # keep firing rather than being skipped to a date months away. Doing the
    # work means bumping `from` in reminders.yml, which is a commit and
    # therefore a record of when it was last actually done.
    return date.fromisoformat(str(r["from"])) + timedelta(days=days)


def open_ids():
    """Reminder ids that already have an open issue, from the body marker."""
    out = sh(["gh", "issue", "list", "-R", REPO, "--state", "open",
              "--limit", "200", "--json", "body"]).stdout or "[]"
    found = set()
    for i in json.loads(out):
        m = re.search(MARKER + r"\s*(\S+)", i.get("body") or "")
        if m:
            found.add(m.group(1))
    return found


def create(r, due, dry):
    body = (r.get("body", "").rstrip() +
            f"\n\nDue **{due.isoformat()}**.\n\n"
            f"<!-- {MARKER} {r['id']} -->\n"
            "Raised automatically from `ops/reminders.yml`. Closing this "
            "acknowledges it; a recurring reminder returns on its next cycle.")
    if dry:
        print(f"  WOULD CREATE  {r['id']}  due {due}")
        return
    url = sh(["gh", "issue", "create", "-R", REPO, "--title", r["title"],
              "--body", body, "--assignee", OWNER,
              "--label", "priority:" + r["priority"]]).stdout.strip().splitlines()[-1]
    item = json.loads(sh(["gh", "project", "item-add", PROJECT_NUMBER, "--owner",
                          OWNER, "--url", url,
                          "--format", "json"]).stdout)["id"]
    q = (
        'mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){updateProjectV2ItemFieldValue('
        'input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}})'
        '{projectV2Item{id}}}'
    )
    targets = [
        (STATUS_FIELD, TODO),
        (AREA_FIELD, AREAS.get(r["area"], AREAS["Tech"])),
        (PRIORITY_FIELD, PRIORITIES.get(r["priority"], PRIORITIES["p3"])),
    ]
    for field, opt in targets:
        sh(["gh", "api", "graphql", "-F", f"p={PROJECT_ID}", "-F", f"i={item}",
            "-F", f"f={field}", "-F", f"o={opt}", "-f", f"query={q}"])
    print(f"  RAISED  {r['id']}  due {due}  -> {url}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = Path(__file__).resolve().parent.parent / "ops" / "reminders.yml"
    reminders = yaml.safe_load(path.read_text())["reminders"]
    today = date.today()
    existing = open_ids()

    raised = 0
    for r in reminders:
        due = next_due(r, today)
        days = (due - today).days
        if r["id"] in existing:
            print(f"  open already   {r['id']:<24} due {due} ({days}d)")
        elif days <= r["warn_days"]:
            create(r, due, args.dry_run)
            raised += 1
        else:
            print(f"  not yet due    {r['id']:<24} due {due} ({days}d)")
    print(f"reminders: {len(reminders)} tracked, {raised} raised")

    # Ping only on a clean run. A reminder job that dies quietly is worse than
    # none — you simply never get the reminder, which is the failure it exists
    # to prevent. Silence here pages, same posture as the backup and drill jobs.
    hb = os.environ.get("REMINDERS_HEARTBEAT_URL")
    if hb:
        try:
            urllib.request.urlopen(hb, timeout=10).read()
        except Exception as exc:
            print(f"  heartbeat ping failed: {exc}", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"reminders FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
