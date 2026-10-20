#!/usr/bin/env node
/**
 * Commit-message gate, run by .githooks/commit-msg.
 *
 * Every rule here was a CLAUDE.md line that got skipped: hundreds of
 * Co-Authored-By trailers had to be stripped from one project's history, and
 * work landed without the issue it belonged to.
 *
 * Usage:  node scripts/check-commit-msg.mjs <message-file>
 */
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

// Paths whose changes the owner tests in the browser before the issue closes
// (the closing rule in CLAUDE.md). Adapt to the layout.
const VISIBLE = /^(src|frontend\/src)\//;

const raw = readFileSync(process.argv[2], 'utf8');
const scissors = raw.indexOf('# ------------------------ >8 ------------------------');
const msg = (scissors === -1 ? raw : raw.slice(0, scissors))
  .split('\n').filter((l) => !l.startsWith('#')).join('\n').trim();
const subject = msg.split('\n')[0];

if (!msg || /^(Merge|Revert) /.test(subject)) process.exit(0);

const problems = [];

if (/^co-authored-by:/im.test(msg)) {
  problems.push('Co-Authored-By trailer. Commits carry one author; remove the line.');
}
if (/\p{Extended_Pictographic}/u.test(msg)) {
  problems.push('Emoji in the message. No emojis, anywhere.');
}
if (!/#\d+/.test(msg) && !/^(typo|chore\(trivial\)):/i.test(subject)) {
  problems.push('No issue reference. Add the issue (e.g. "(#12)" or "Closes #12"), or start the subject with '
    + '"typo:" / "chore(trivial):" for the untracked cases CLAUDE.md allows.');
}
// Closing rule: visible work waits in Review for the owner's test, so a commit
// touching it may not auto-close its issue.
const staged = execFileSync('git', ['diff', '--cached', '--name-only'], { encoding: 'utf8' }).split('\n');
if (staged.some((f) => VISIBLE.test(f)) && /\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#\d+/i.test(msg)) {
  problems.push('Auto-closing keyword on a visible change. Reference the issue as "(#n)" only; it moves to Review after '
    + 'the deploy and closes when the owner has tested it.');
}
for (const line of msg.split('\n').filter((l) => /^gate:\s*skipped/i.test(l))) {
  if (!/^gate:\s*skipped\s*[—-]+\s*owner approved:\s*".+"\s*$/i.test(line)) {
    problems.push(`Malformed skip line: ${line}\n      Expected: Gate: skipped — owner approved: "<the owner's exact words>"`);
  }
}

if (problems.length) {
  console.error('');
  console.error('Blocked: commit message (rule gates)');
  for (const p of problems) console.error(`  - ${p}`);
  console.error('');
  process.exit(1);
}
