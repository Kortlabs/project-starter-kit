# Project starter kit

The working setup a new project starts with: the rules file an AI assistant reads every session, the
guardrails that make a bad commit impossible, and the small scripts that make a claim of "done"
verifiable.

Extracted from Kliper in September 2026, after two years of rules that each arrived the same way —
something went wrong, and the fix got written down. A new project inherits the fix without the incident.

---

## What you get

| File | What it does |
|---|---|
| `CLAUDE.md` | The rules an assistant loads every session. Placeholders marked `{{LIKE_THIS}}`. |
| `docs/ways-of-working.md` | The process around the rules: who decides what, the loop, verification, where knowledge lives. |
| `docs/tech-stack.md` | An inventory template, so "what do we run and why" has an answer from day one. |
| `.githooks/pre-commit` | Three layers: never-track paths, editorconfig on staged files, an optional per-project check. |
| `.editorconfig` + `.editorconfig-checker.json` | Whitespace and indentation, enforced rather than requested. |
| `ops/reminders.yml` + `scripts/check-reminders.py` | Dated commitments become GitHub issues before they come due. |
| `scripts/verify-pages.mjs` | Playwright: visit the real pages, screenshot them, fail on console errors. |
| `scripts/deploy.sh` | A deploy that builds first, aborts before touching the running service, and health-checks after. |

Also read [docs/why.md](docs/why.md) — one paragraph per guardrail explaining the incident behind it. It
is short, and it is the difference between following a rule and understanding it.

---

## Install

From inside the target repository:

```bash
git clone git@github.com:Crushoverride007/project-starter-kit.git /tmp/kit
/tmp/kit/install.sh --name "FactureLab" --repo "Crushoverride007/facturelab"
```

The installer copies the template in, fills the placeholders it was given, appends the never-track block
to your `.gitignore` rather than overwriting it, and points git at the tracked hooks directory. It never
overwrites an existing file — anything already present is reported and skipped, so running it twice is
safe.

Then, by hand:

- Fill the remaining `{{PLACEHOLDERS}}` in `CLAUDE.md`. The project board identifiers are the fiddly
  ones; `install.sh --print-board-help` shows how to fetch them.
- Delete the sections that do not apply. A rules file nobody trusts is worse than a short one.
- Adapt `scripts/deploy.sh` and `scripts/verify-pages.mjs` to how this project actually builds and runs.

---

## The one rule that matters most

Every rule in `CLAUDE.md` should be traceable to something that actually happened. Rules invented in
advance get ignored, because nobody believes them. When a correction is given, write it down in the place
that will be read next time — that is the whole method, and the rest of this kit is just scaffolding for
it.
