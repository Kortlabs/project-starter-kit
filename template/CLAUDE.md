# {{PROJECT_NAME}} — Project Instructions

Rules that override default behaviour. Keep this file short enough that it is actually read. The process
around these rules lives in [docs/ways-of-working.md](docs/ways-of-working.md); the technology inventory
in [docs/tech-stack.md](docs/tech-stack.md).

---

## Quality standards (mandatory)

**Cost is not a constraint. Correctness is.** Spend generously on understanding and verification; spend
nothing on speculation.

### Before editing any file
1. **Read the whole file**, not a slice. You cannot safely change code you have not read.
2. **Grep for callers** of anything whose signature you are about to change.
3. **Check for an existing utility** before writing a new one. Duplicated logic is a regression.
4. **State your understanding** before a non-trivial change, so a wrong reading costs a sentence.

### Before debugging
1. **Ask for the error, the console, the network log or a screenshot.** One real error message is worth
   ten file reads.
2. **State a hypothesis first.** If you cannot form one, you do not understand the problem yet — ask.
3. **Test the cheapest hypothesis first** with a search, then targeted reads.
4. **Find the root cause.** A symptom-level patch today is a regression next month.

### While writing code
1. **Every changed line traces back to the request.** If it does not, delete it.
2. **Reject over-engineering.** No defensive handling for what cannot happen, no helper used once, no
   config nobody asked for, no comments restating the code.
3. **Match the surrounding patterns.** Stylistic drift is itself a defect.
4. **Validate at real boundaries only** — user input and external APIs. Trust internal code.

### Flag, don't act
Noticing an unrelated problem while working in a file means **telling the owner**, not silently fixing it.
Scope creep dressed as helpfulness is still scope creep. The exception is cleaning up orphans your own
change created.

---

## Verify before claiming

"It works" is not a claim to make from reading the code. Before reporting anything as done:

- {{VERIFY_COMMAND}} — the project's own verification script
- Services healthy after a deploy, and the health endpoint answering
- For anything crossing a system boundary, exercise it end to end. An API that returns 200 has not
  proven the mail arrived.

---

## Git staging — explicit paths only

- **Never `git add -A`, `git add .`, or `git add --all`.** Stage named paths.
- Untracked directories in this repo may hold large, private or scratch content. One careless bulk add
  puts them in history and forces a rewrite to remove.
- A tracked pre-commit hook in `.githooks/` blocks the worst cases. Enable it once per clone:
  `git config core.hooksPath .githooks`
- Correct pattern: `git add path/one.ts path/two.md && git commit -m "…"`

---

## Commit style

- {{COMMIT_STYLE}}
- Subject in the imperative, explaining the change rather than the file touched.
- The body explains **why**, especially the constraint or incident behind the change.

---

## Issue tracking — log first, work second

For a bug, a regression, or focused feature work: **create the issue before writing code**, then start.

1. Create it on `{{REPO}}` with the symptom, the repro and the context.
2. Assign it to `{{OWNER}}`.
3. Add it to the project board and set Status, Area and Priority.
4. Reference it in the commit (`Closes #123`) so the merge closes it.

**Skip it for** typos, single-character fixes, and anything the owner says not to track.

Board identifiers, needed by the command above and by `scripts/check-reminders.py`:

```
Project ID:      {{PROJECT_ID}}
Status field:    {{STATUS_FIELD}}   (Todo {{STATUS_TODO}}, In Progress {{STATUS_IN_PROGRESS}})
Area field:      {{AREA_FIELD}}
Priority field:  {{PRIORITY_FIELD}}
```

---

## Dated commitments go in `ops/reminders.yml`

Anything due on a **date** rather than in response to an event — a credential expiring, a certificate, a
recurring drill — belongs in that file, not in prose inside a document. A cron reads it daily and opens
an issue when one enters its warning window, so the date arrives where work already lives.

Do not write "expires 2027-10-02" into a runbook paragraph and consider it tracked.

---

## Deployment

{{DEPLOY_NOTES}}

Two rules that generalise regardless of stack:

- **A failed build must never reach the running service.** Build first, abort on failure, only then swap.
- **Reload rather than restart** where the process manager supports it, so in-flight requests survive.

---

## Secrets

- Runtime configuration lives in `.env` files that are gitignored. Operator credentials — the ones a
  human minted for infrastructure rather than for the app — live in `ops/.env.*`, mode 600.
- Nothing at runtime reads from a secrets vault. A vault is a disaster-recovery record; making it a boot
  dependency turns a vault outage into an application outage.
- Never commit a secret. If one is committed, rotate it rather than only removing it from history.

---

## {{DOMAIN_SECTION_TITLE}}

{{DOMAIN_SECTION_BODY}}

<!--
Sections worth adding as the project earns them, each only once it has:
  - Read-on-demand pointers to deeper references, with an explicit "do NOT read for" list
  - Branding and naming rules, if a name differs between code and product
  - No-touch zones: files that must never be edited, and what to change instead
  - Documentation rules: where docs live and what shipping one requires
  - Testing conventions
  - Anything an assistant got wrong twice
-->
