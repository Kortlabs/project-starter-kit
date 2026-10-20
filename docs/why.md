# Why each guardrail exists

Every rule in this kit was paid for. Skipping one is a choice to pay again.

---

**Explicit git staging, never `git add -A`.** A bulk add once swept runtime uploads, design mockups and
vendor assets into a commit that reached the main branch and had to be force-removed. The uploads were
real customer evidence. `.gitignore` had rules for all of it, but the rules only match what they
anticipate, and a directory added last week is not anticipated.

**A pre-commit hook, tracked in the repo.** `.gitignore` does not stop `git add -f`, and a hook in
`.git/hooks` does not survive a fresh clone. Putting the hook in `.githooks/` and pointing git at it
makes the guard travel with the code. The hook that lives only on one machine protects only one machine.

**Editorconfig checked on staged files only.** Checking the whole tree fails on every pre-existing
violation, so it gets disabled within a week. Checking only what this commit touches catches new mess
without gating on old mess, and people keep it.

**Verify in a browser, not with curl.** A page can return 200 and throw on mount. An endpoint can return
200 and drop the message. Both have happened. The rule that survives is: prove the outcome, not the
status code. When mail is involved, confirm it arrived in the mailbox.

**Build before touching the running service.** A deploy that builds in place takes production down when
the build fails, at the exact moment you are least prepared. Build first, abort on failure, swap only a
verified artefact.

**Reload rather than restart.** Measured on a clustered service: restart dropped four requests and gave
a visible outage of a second or two; reload dropped none, because workers cycle one at a time.

**Dated commitments in a file a machine reads.** Expiry dates written into runbook prose are findable
only by grepping for a date you already remembered. A certificate expiring is not a surprise, it is a
calendar event, and it belongs where the work is — as an issue that opens before the date.

**A backup step that warns instead of aborting, but refuses an empty archive.** A storage backup once
failed every night for weeks while the heartbeat stayed green, because nothing checked the result. An
empty archive is the dangerous case: it looks exactly like success. Check the size, and let a
non-critical step warn rather than suppress the signal that the critical step worked.

**Secrets in gitignored ops files, mirrored to a vault, never read at runtime.** A credential that lives
only on one disk is not backed up. But making the vault a boot dependency turns a vault outage into an
application outage, which trades a rare problem for a common one.

**A code review before shipping, advisory.** Every gate a one-person, AI-built project has is mechanical:
lint, whitespace, blocked paths, a browser check that the page mounts. None of them reads the logic, and
the bug that keeps recurring is the one a read catches: a control wired to the wrong column that silently
does nothing, a change that passed its unit test and still shipped broken. So the diff gets a second read,
per issue before the shipping commit and per deploy over everything since the last tag. Advisory on
purpose: a review finding is a judgment, and blocking a hotfix on a false positive costs more than the bug
it might catch. Hosted pull-request reviewers never fire on a project that ships straight to main.

**Rule gates on staged changes, with a visible escape.** A rule that lives only in a rules file gets
skipped when the session is long. Encoding the mechanically checkable ones as a pre-commit layer means a
commit that breaks them is refused, whatever mode the assistant runs in. Added lines only, so old
violations never block new work. The escape is a marker on the line with the owner's reason, printed on
every run and counted in the daily report: an exception nobody sees becomes the norm.

**A commit-message gate.** Hundreds of Co-Authored-By trailers had to be stripped from one project's
history, and work kept landing without the issue it belonged to. Both were rules in prose for months.

**The gate files are gates too.** A guard that can be edited by the thing it guards is decoration. The
hook scripts, the check scripts, the settings file and the hooks directory need the owner's quoted
approval to change, like any other bypass.

**Every bypass is announced three ways.** The owner's exact words in the command prefix or the commit,
a warning in the chat, a comment on the issue, a line in the daily report with the quote. Nothing can
verify the owner said the words; making them visible in three places is what makes a forged approval
stand out.

**Claude Code hooks that run in every permission mode.** Auto-accepting commands is not the same as
bypassing rules. The command guard refuses the no-verify flag, a redirected hooks path, a bulk `git add`,
a service restart and a change to the gates themselves, in `bypassPermissions` as much as in default mode.

**A Stop hook.** "Done" was claimed over a known rule violation sitting uncommitted in the tree. The
turn cannot end while that is true; the second stop in a row passes so it never loops, and the violation
is logged either way.

**A pre-push guard on main.** The one git operation that is hard to undo is a history rewrite on the
default branch. Everything else is a revert away.

**The owner's test is the last step, not a gate.** Blocking the deploy on a browser test stalled work
for days. Visible work now ships, moves its card to Review with a note on what to test, and closes when
the owner confirms; invisible work closes on push. The report names what has waited more than three days.

**Deploy tags.** "What was live when" used to need archaeology. A tag after every passed health check
makes the rollback list and the review range for the next deploy a one-line `git tag -l`.

**A daily report of one phone screen.** The owner stopped reading long status text; a report that does
not fit one screen is not read either. Only the lines with something to say render, so a green day is
three lines, and each line was added after its question had been asked twice.

**Assistant-pace estimates.** "~1 day" is a billing convention the assistant learned from humans; the
owner plans against the assistant's output, where the same work is 30 minutes and five commits.
Engineer-day framing made everything sound bigger than it was.

**Label verified against opinion, and never fold silently.** The owner asked whether answers were being
shaped to please him, and sometimes they were: a recommendation collapsed on the first objection, and
plausible items were listed beside verified ones in the same tone. A reversal with no stated reason means
the first answer was never grounded.

**Verify before proposing.** The assistant proposed building things that had shipped weeks earlier,
reciting its own notes. A repo that moves at hundreds of commits a month outruns any note; the check is a
grep, and the claim is "verified at <path>" or "unverified".

**Test the owner's path.** A feature had passing unit tests and did nothing on the data the owner tests
with, because every row there hit the one branch nobody had clicked. Logic tests prove the logic; the
feature is proved by clicking it where the owner will.

**Short answers.** "My brain gets fatigued; by the third time I just skip." Long summaries are not
merely expensive, they stop being read, and the one line that mattered goes with them.

**No secret values in chat.** Chat text travels further than tool output: extensions, transcripts,
pastes. Name the variable and the file, never the value, and mask anything random-looking before it
reaches the output.

**Interactive shell aliases lie.** A profile with `rm -i`, `cp -i`, `mv -i` makes a non-interactive
overwrite prompt, get no answer, do nothing and exit 0, so the `&& echo done` after it is false. Twice
in one session. Use `command cp -f`, `command rm -r --`, and check the result.

**Long builds run detached, at low priority, with a heap cap.** A build run inline in an SSH session
took the server to swap, killed the owner's editor session and ended in a hard reboot that wiped the
build artefact. A build is also never killed mid-way, and only a confirmed commit is deployed.

**No destructive server action without an in-the-moment yes.** An editor that would not connect was a
client-side VPN problem; the assistant killed the wrong editor's server processes and then the right
one's, turning a two-minute fix into an hour and a loss of trust. Diagnose read-only, propose, stop.

**Docker bypasses the host firewall.** A container port published on 0.0.0.0 is open to the internet
whatever `ufw status` says, because Docker's chain is evaluated first. A cache that had "ALLOW from
127.0.0.1" counted thirty thousand password guesses. Only `DOCKER-USER` rules count; verify from another
host, not from the firewall's own output.

**Temporary test data is visible.** A check that creates and deletes rows in the shared demo had the
owner open the row while it existed and watch it vanish. Say so before running, in one line.

**Sample one when pages share a template.** Twelve pages rendered from one template were scanned twelve
times, twice. One representative page answers for all of them; sweep more only when the content differs.

**Flag, don't act.** An assistant that silently fixes unrelated things it notices produces commits nobody
asked for and cannot review. Noticing is valuable; acting on it unasked is scope creep.

**Write the correction down where it will be read next.** The same mistake repeating three times is not
a memory problem, it is a documentation problem. A rule that lives only in a conversation is not a rule.
