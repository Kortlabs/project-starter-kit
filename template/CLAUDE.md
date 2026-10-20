# {{PROJECT_NAME}} — Project Instructions

Rules that override default behaviour. Keep this file short enough that it is actually read. The process
around these rules lives in [docs/ways-of-working.md](docs/ways-of-working.md); the technology inventory
in [docs/tech-stack.md](docs/tech-stack.md).

---

## Effort estimates: assistant-pace, not engineer-days

The assistant does the work, so "~1 day" or "~3-4 days" is a billing convention from training data and
4-8x too high. Estimate in what the owner will experience: wall-clock time of the assistant's work
("~30 min"), sessions ("~2 sessions"), commits ("~5 commits"), or concrete scope ("3 files, 1 new
component"). When unsure, describe the scope and skip the duration.

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

### Disagreement and confidence
Added after the owner asked whether answers were being shaped to please him. Sometimes they were.
- **Label the basis.** A claim is verified, naming the command, output or file it rests on, or it is an
  opinion and says so. Never both in the same confident tone.
- **Don't reverse without a reason.** On pushback, state the new evidence or hold the position and say
  why. A silent fold means the first answer was never grounded.
- **Give the counter-case unasked.** A recommendation carries its strongest objection.

### Verify before proposing
Never propose work from a memory note without checking the code first. A fast-moving repo makes a
six-week-old note wrong more often than right. Say "verified present at <path>", not "per my notes".
Before surfacing an idea, grep for what already exists and show "have vs adds".

### Test the owner's path
Before reporting a feature as working, click it through on the data the owner tests with, in a headless
browser, with writes intercepted. Unit tests on the logic once passed while the feature did nothing on
the owner's demo. Say which parts were unit-tested and which were clicked through.

### Short answers
Summaries, status recaps and answers are 2-3 sentences. Lead with the one fact that matters; detail on
request. The owner stops reading long text and the important line gets missed. Work products (commit
messages, issue bodies, docs) stay thorough.

### Never in chat
- **Secret values.** Name the variable and the file ("the token in `ops/.env.cloudflare`"), never the
  value, not even partially. Mask anything long and random-looking in tool output.
- **Destructive server actions unprompted.** No killing processes, restarting services or touching
  editor and session infrastructure without an in-the-moment yes. Diagnose, propose, stop.
- **Shell traps.** Interactive `rm`/`cp`/`mv` aliases prompt, get no answer, do nothing and exit 0; use
  `command rm -r --`, `command cp -f`, and verify afterwards.
- **Test data the owner can see.** A check that creates rows in the shared demo must say so first;
  the owner browses the same data.

---

## Verify before claiming

"It works" is not a claim to make from reading the code. Before reporting anything as done:

- {{VERIFY_COMMAND}} — the project's own verification script
- Services healthy after a deploy, and the health endpoint answering
- For anything crossing a system boundary, exercise it end to end. An API that returns 200 has not
  proven the mail arrived.

---

## Code review before shipping

Two layers, neither a gate. Hooks block on deterministic rules only; a review finding is a judgment, and a
false positive must not hold a hotfix.

- **Per change, while working.** Before the commit that ships an issue, run `/code-review` on the diff. It
  runs as a background subagent, so it overlaps the verification script. Fix the findings in the same
  commit, which is the cheapest moment to fix anything; name the ones deliberately left in the commit
  message. Typo and trivial-chore commits are exempt.
- **Per deploy, the net.** `scripts/deploy.sh` reviews everything since the last deploy tag alongside the
  build and prints the findings after the health check. It never aborts the deploy. Whoever runs the
  deploy reads the findings and fixes or relays them.

Why two: a rule can be skipped and a script cannot, and the deploy review sees a day's commits together,
which catches two changes that each look fine alone. Hosted pull-request reviewers only fire on pull
requests; a project that ships straight to its main branch needs the review in the session and in the
deploy script instead.

---

## Gates, and how a bypass is seen

Rules that live only in prose get skipped. These run on every commit and in every permission mode:

- **`.githooks/pre-commit`**, five layers: never-track paths; editorconfig on staged files; the project's
  own check (`scripts/pre-commit-check.sh`); ESLint on staged source; rule gates (`scripts/check-rules.mjs`,
  one rule per incident, added lines only).
- **`.githooks/commit-msg`**: no Co-Authored-By, no emoji, an issue number (unless the subject starts
  `typo:` or `chore(trivial):`), no auto-close keyword on visible work, a well-formed skip line.
- **`.githooks/post-commit`**: comments any skip or `gate-ok` exception on the commit's issue.
- **`.githooks/pre-push`**: blocks a non-fast-forward push to main and deleting main.
- **Claude Code hooks** (`.claude/settings.json`, `scripts/claude-hooks/`): the command guard refuses
  the no-verify flag, a hooks-path override, `git add -A`/`.`/`--all`, a service restart, and any change
  to the gate files themselves; the edit guard refuses the gate files; the Stop hook refuses to end a
  turn while uncommitted source changes break a rule. `bypassPermissions` auto-accepts commands; it does
  not bypass gates.

**The bypass protocol.** Only the owner can approve an exception, and every one is announced three ways:
- A command the guard refuses runs once with the prefix `GATE_OWNER_OK="<the owner's exact words>"`.
  The guard shows the quote in the chat and logs it to `~/.claude/gate-blocks.log`.
- A commit that skips a gate carries the line `Gate: skipped — owner approved: "<the owner's exact words>"`.
- A line that breaks a rule the owner accepted carries `gate-ok: <rule-id> <reason>`.
- The post-commit audit comments the skip or exception on the issue; the daily report's GATES line counts
  them and shows the quotes. The assistant also says it plainly in its own message, same turn: which gate,
  and the words used. Nothing can verify the owner said them; this is where the owner checks.

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
4. Reference it in the commit. **Visible work** (anything the owner sees in the browser): `(#123)` only;
   after the deploy, set the card to `Review` and say exactly what to test; it closes when the owner
   confirms. **Invisible work** (backend-only, docs, scripts, dependencies): `Closes #123`; it closes on
   push once the deploy is verified. The owner's test is the last step, not a gate.
5. The card moves to `Done` only through the board's built-in "Item closed" workflow. If closed issues
   pile up in To do or In Progress, that toggle is the first thing to check.

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
- **Long builds run detached, at low priority, with a heap cap** (tmux, `nice -n 10`, a `--max-old-space-size`).
  A build run inline in an SSH session once took the whole server down and the editor session with it.
- **Never kill a running build**, and deploy only a confirmed commit: a build killed mid-way left the
  running service pointing at a half-written artefact.
- **Every deploy is tagged** (`deploy/YYYYMMDD-HHMM`, pushed) after the health checks pass, so
  `git tag -l 'deploy/*'` is the list of known-good rollback targets and the review range for the next deploy.

---

## Secrets

- Runtime configuration lives in `.env` files that are gitignored. Operator credentials — the ones a
  human minted for infrastructure rather than for the app — live in `ops/.env.*`, mode 600.
- Nothing at runtime reads from a secrets vault. A vault is a disaster-recovery record; making it a boot
  dependency turns a vault outage into an application outage.
- Never commit a secret. If one is committed, rotate it rather than only removing it from history.

---

## The daily report

`scripts/daily-report.py` prints one phone screen a day: WORK (issues and deploys), GATES (skips,
escapes, blocked and owner-approved commands, with the quotes), REVIEW (cards waiting for the owner's
test, naming any older than 3 days). Cron it to the owner's mail. Add a line when a question gets asked
twice; cut when it no longer fits one screen.

---

## Web UI rules (delete for a non-web project)

- **No native browser UI.** No `<select>`, `window.confirm`/`alert`/`prompt`, `<input type="date">`,
  `title=` tooltips or native radios once the project has its own components. Touching a component that
  still has one means replacing it in the same change. `scripts/check-rules.mjs` enforces the list.
- **The design system is one file** that every token, size and component recipe is read from. When a
  token or a control size changes, that file changes in the same commit; it must never drift from the
  stylesheet and the component code. Add rule gates for the sizes the owner has had to correct twice.
- **Signal off-screen results.** Content that appears outside the viewport after an action gets a
  persistent affordance (a pinned jump pill with a count), not only a toast.
- **Sample one when pages share a template.** Verify one representative page; sweep more only when the
  content differs, and say why.

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
