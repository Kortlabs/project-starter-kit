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

**Flag, don't act.** An assistant that silently fixes unrelated things it notices produces commits nobody
asked for and cannot review. Noticing is valuable; acting on it unasked is scope creep.

**Write the correction down where it will be read next.** The same mistake repeating three times is not
a memory problem, it is a documentation problem. A rule that lives only in a conversation is not a rule.
