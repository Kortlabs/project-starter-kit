# How we work

How software actually gets made on {{PROJECT_NAME}}, as opposed to the rules it must follow. The rules
live in [CLAUDE.md](../CLAUDE.md); this is the process around them.

If you are joining, read this first, then CLAUDE.md.

---

## Who does what

{{TEAM_DESCRIPTION}}

**The owner decides** what gets built, whether it looks right, and whether it is true. Aesthetic
judgement, product judgement, anything with legal or commercial consequence, and anything outward-facing:
publishing, sending mail to a real person, changing DNS, deleting data.

**The assistant does** implementation and verification. Reads before changing, states assumptions before
acting on them, builds, proves the result rather than asserting it, and reports exactly what to check.

The division is about information, not seniority. The assistant cannot see the screen, cannot judge
whether a page feels right, and does not know what was promised to a customer.

---

## The loop

1. **A problem arrives**, usually as a sentence and a screenshot. Screenshots are the highest-value input
   there is.
2. **Investigate before proposing.** State a hypothesis, test the cheapest one first.
3. **Log an issue before writing code** for anything worth tracking.
4. **State the plan and the assumptions** for anything non-trivial.
5. **Build**, matching the patterns already there.
6. **Verify.** This is the step that separates working software from software that returns 200.
7. **Review the diff** before the commit that ships an issue: `/code-review` on the change, findings fixed
   in the same commit. The deploy script reviews everything since the last deploy tag as a net. Neither
   one blocks.
8. **Deploy** with the documented commands, never by improvising.
9. **Report what to test.** The owner does the real functional and aesthetic testing.
10. **Document it** when a shipped feature warrants it.

---

## Verification

| Method | What it proves |
|---|---|
| `node scripts/verify-pages.mjs` | The real pages render, with no console errors or failed requests. Screenshots can be read directly. |
| `/code-review` on a diff | A second read of the change for correctness bugs: a control wired to the wrong field, a caller a signature change missed, an edge case the happy path skips. Per issue before the shipping commit, and again in `scripts/deploy.sh` over everything since the last deploy tag. Advisory, never a gate. |
| A one-off browser script | Anything specific: measuring an element, exercising a form, diffing two states. Write it, run it, delete it. |
| Health checks after deploy | The service actually came back. |
| A real end-to-end request | For anything involving another system. Do not trust a 200. |

The failure mode this guards against: a deploy that returns 200 while the page throws on mount; an API
that accepts a message and silently drops it; a control wired to the wrong field so it quietly does
nothing.

---

## What the assistant can and cannot do

Knowing the boundary saves time on both sides. Adjust this list to what is actually true here.

**Can.** Read and write files; run commands; use git and the GitHub CLI; deploy; drive a headless browser
and read the screenshots it takes; call the APIs whose credentials are configured.

**Cannot.** See your screen. Know what a page looks like without screenshotting it. Remember anything
from a previous session except what is in its memory. Judge whether a design is good.

**Will not without being asked.** Kill processes, restart services, delete data, force-push, publish
anything outward-facing, or send mail to a real person. Approval for one does not carry to the next.

---

## Where knowledge lives

| Where | Holds | Authority |
|---|---|---|
| [CLAUDE.md](../CLAUDE.md) | The rules | Binding, loaded every session |
| `docs/` | References read on demand | Canonical for their subject |
| The assistant's memory | Corrections, settled decisions, hard-won facts | Context, not truth — verify before acting |
| `ops/reminders.yml` | Anything due on a date | Binding, raises an issue when near |
| [tech-stack.md](tech-stack.md) | Every technology and why | Canonical inventory |

**Verify before proposing.** A fast-moving codebase makes a six-week-old note describe something that no
longer exists. Never propose work from memory without checking the code first.

---

## How rules get made

Nearly every rule should be traceable to something that went wrong. Rules invented in advance get
ignored, because nobody believes them.

When a correction is given, it gets written down in the place that will be read next time. A rule that
lives only in a conversation will be broken again in three weeks.

---

## Continuity

Sessions do not persist. Long conversations get summarised as they grow, and each new session starts
without recollection of the last. Three things carry knowledge across: the rules file, the assistant's
memory directory, and whatever was written into the repository.

**Back up the memory directory.** It is not in git and it holds every correction ever given. Losing it
means repeating months of them. A nightly tar to object storage is enough.
