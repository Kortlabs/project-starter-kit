#!/usr/bin/env python3
"""Daily report: the lines that keep a one-person, assistant-driven project honest.

  WORK    issues opened / closed / open, deploys (deploy/* tags)
  GATES   skipped gates, gate-ok escapes, blocked and owner-approved commands
  REVIEW  cards waiting in Review for the owner's test, and any older than 3 days

Prints text; pipe it to whatever delivers mail. Needs `gh` signed in.

  python3 scripts/daily-report.py --repo owner/name --board-owner org --board-number 4
  cron:  0 17 * * * cd /path/to/repo && python3 scripts/daily-report.py --repo owner/name \\
           --board-owner org --board-number 4 | mail -s "daily" you@example.com

The project this came from grew STATUS (uptime, restarts, disk), ERRORS, USERS,
BACKUPS and SECURITY lines on top of these. Add a line when a question gets
asked twice; keep the whole report to one phone screen, and cut when it grows.
"""
import argparse
import datetime as dt
import json
import os
import subprocess

GATE_LOG = os.path.expanduser("~/.claude/gate-blocks.log")
SRC_DIRS = ["src"]  # keep in step with scripts/claude-hooks/lib.sh


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=90).stdout.strip()


def sect_work(repo, since):
    d = since.strftime("%Y-%m-%dT%H:%M:%SZ")

    def count(q):
        return int(sh(f'gh api "search/issues?q=repo:{repo}+is:issue+{q}" --jq .total_count') or 0)

    opened, closed, open_n = count(f"created:>={d}"), count(f"closed:>={d}"), count("is:open")
    tags = [t for t in sh("git tag -l 'deploy/*'").split() if t[7:20] >= since.strftime("%Y%m%d-%H%M")]
    return f"WORK      issues +{opened} / -{closed} · open {open_n} · deploys {len(tags)}"


def sect_gates(since):
    # A skip needs the owner's words, and nothing can verify they were said;
    # this line is where the owner checks. Quotes are shown so a skip never
    # approved stands out.
    iso = since.strftime("%Y-%m-%dT%H:%M:%SZ")
    msgs = sh(f"git log --since={iso} --format=%B").splitlines()
    skips = [l.split("owner approved:", 1)[-1].strip() for l in msgs if l.lower().startswith("gate: skipped")]
    diff = sh(f"git log --since={iso} -p -- {' '.join(SRC_DIRS)}").splitlines()
    escapes = sum(1 for l in diff if l.startswith("+") and "gate-ok:" in l)
    rows = [l.split("\t") for l in open(GATE_LOG, errors="replace").read().splitlines()] if os.path.exists(GATE_LOG) else []
    rows = [r for r in rows if len(r) >= 5 and r[0] >= iso]
    blocked = sum(1 for r in rows if r[1] == "BLOCKED")
    allowed = [f'"{r[4]}" ({r[2]})' for r in rows if r[1] == "ALLOWED"]
    quotes = (skips + allowed)[:3]
    return (f"GATES     skips {len(skips)} · escapes {escapes} · blocked {blocked} · owner-approved {len(allowed)}"
            + (" — " + "; ".join(quotes) if quotes else ""))


REVIEW_QUERY = """query($owner:String!,$number:Int!,$after:String){ %s(login:$owner){ projectV2(number:$number){
  items(first:100, after:$after){ pageInfo{ hasNextPage endCursor } nodes{
    fieldValueByName(name:"Status"){ ... on ProjectV2ItemFieldSingleSelectValue { name updatedAt } }
    content{ ... on Issue { number title } } } } } } }"""


def sect_review(owner, number, kind):
    # Visible work waits in Review until the owner has tested it. A card left
    # there more than three days comes back here so it is not lost.
    waiting, after = [], None
    query = REVIEW_QUERY % kind
    while True:
        cmd = f"gh api graphql -f query='{query}' -F owner={owner} -F number={number}" + (f" -F after={after}" if after else "")
        page = json.loads(sh(cmd) or "{}")
        items = page["data"][kind]["projectV2"]["items"]
        for n in items["nodes"]:
            st = n.get("fieldValueByName") or {}
            if st.get("name") == "Review" and (n.get("content") or {}).get("number"):
                age = (dt.datetime.utcnow() - dt.datetime.strptime(st["updatedAt"][:19], "%Y-%m-%dT%H:%M:%S")).days
                waiting.append((age, n["content"]["number"], n["content"]["title"]))
        if not items["pageInfo"]["hasNextPage"]:
            break
        after = items["pageInfo"]["endCursor"]
    stale = sorted((w for w in waiting if w[0] > 3), reverse=True)
    line = f"REVIEW    {len(waiting)} waiting for your test"
    if stale:
        line += f" · {len(stale)} over 3 days: " + ", ".join(f"#{num} {title[:40]} ({age}d)" for age, num, title in stale[:3])
    return line


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="owner/name")
    ap.add_argument("--board-owner", help="GitHub org or user that owns the project board")
    ap.add_argument("--board-number", type=int, help="project board number")
    ap.add_argument("--board-kind", choices=["organization", "user"], default="organization")
    ap.add_argument("--hours", type=int, default=24)
    a = ap.parse_args()
    since = dt.datetime.utcnow() - dt.timedelta(hours=a.hours)

    lines = [sect_work(a.repo, since), sect_gates(since)]
    if a.board_owner and a.board_number:
        lines.append(sect_review(a.board_owner, a.board_number, a.board_kind))
    print(f"{a.repo} — last {a.hours}h")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
