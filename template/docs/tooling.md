# Tooling

What the assistant works with on {{PROJECT_NAME}}, and which parts the method depends on. Keep it
current: a tool listed here that is no longer installed costs a session to rediscover.

---

## Required by the method

| Tool | Used for | Notes |
|---|---|---|
| Claude Code | The assistant itself, in a terminal on the server | `/code-review` with a commit range, `--max-findings` and headless `-p` need v2.1.288 or later |
| `/code-review` (bundled skill) | The per-change review before a shipping commit, and the headless review in `scripts/deploy.sh` | Works on any plan, counts toward the session's usage. `/code-review ultra` is the deeper cloud review: owner-triggered, billed, never in a script |
| `gh` CLI | Issues, the project board, PR and release calls, the gate audit comment, the daily report | Signed in as the owner. Authenticated API calls go through it, never through a token in a script |
| `jq` | The Claude Code hooks read their JSON input with it | A hook that cannot find `jq` fails open; check it is installed before trusting the gates |
| Node 20+ | `scripts/check-rules.mjs`, `scripts/check-commit-msg.mjs` | No dependencies |
| Python 3 | `scripts/check-reminders.py`, `scripts/daily-report.py` | Standard library only |
| `editorconfig-checker` | Layer 2 of the pre-commit hook | The one root-level npm dependency; keep the root `package.json` to this |
| Playwright (headless) | `scripts/verify-pages.mjs` and one-off checks | The assistant reads the screenshots it takes |

---

## Repo skills

Skills stored in the repository, under `.claude/skills/<name>/SKILL.md`, load when a task matches their
`description`. The project this kit came from keeps one per thing the assistant kept getting wrong
without it: the design system (tokens, sizes, components), the ORM's query patterns, the UI kit's
component recipes, the backend-as-a-service's functions, storage and realtime rules, and a
knowledge-graph tool that is **off by default** because it consumes the same quota as the session.

Frontmatter is two lines:

```yaml
---
name: design-system
description: Build UI for {{PROJECT_NAME}} with the existing design system. Use when creating components, pages or UI elements.
---
```

Write one when a correction has been given twice about the same stack concern; the rules file is for
rules, a skill is for how-to.

---

## Plugins and mods used alongside

None of these is required. Each earned its place on the source project; adopt one when the same need
shows up.

| Plugin | What it gave |
|---|---|
| `caveman` | A terse reply mode for long sessions. The owner reads in a terminal and skips long text; this keeps every fact and drops the rest. Stays on until "stop caveman" |
| `claude-security` | Periodic scans of the codebase, findings verified by a panel of agents and turned into patch files. Scan output is a catalogue of live vulnerabilities until patched: keep it out of git |
| `diagram-design` | Architecture and flow diagrams for the docs as HTML/SVG. No Mermaid, no ASCII art in published docs |
| `data` | Ad-hoc analysis of product analytics and database tables |

**Mods** (changes to the assistant's own interface) were tried and turned off as "clunky for now".
Don't re-propose them without a new reason.

---

## MCP servers

A read-only database connection and the project's own services are reachable as MCP servers when
configured. Treat each the way the secrets rule treats credentials: the connection string lives in a
gitignored file, and a read-only role is the default for anything an assistant can query.

---

## The memory directory

The assistant's own notes, one fact per file, indexed by a `MEMORY.md` the session loads. Not in git.
It holds every correction ever given, so it is **backed up nightly** to object storage, thirty days
kept. A lost memory directory means repeating months of corrections.
