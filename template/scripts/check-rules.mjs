#!/usr/bin/env node
/**
 * Rule gates for staged changes.
 *
 * CLAUDE.md rules that live only in prose get skipped; the ones a script
 * enforces hold. This encodes the mechanically checkable ones so a commit that
 * breaks them is refused, whatever mode the session runs in.
 *
 * Keep the engine. Keep the rules that match your stack, delete the rest, and
 * add one rule per incident: the project this came from also gates its design
 * system (button sizes, control heights, decorative edge bars, a retired layout
 * component), each added after the rule in prose was broken twice.
 *
 * Scope: rules marked `file` check the whole file (touching a component that
 * still has one means replacing it in the same change). Every other rule checks
 * only the lines being ADDED, so pre-existing violations never block unrelated
 * work. `any` fires when the file is part of the change at all.
 *
 * Escape: `gate-ok: <rule-id> <reason>` on the offending line or the line above.
 * Every escape used is printed, and the daily report counts them.
 *
 * Usage:  node scripts/check-rules.mjs <file...>              (staged content, pre-commit)
 *         node scripts/check-rules.mjs --unstaged <file...>   (working tree vs HEAD, Stop hook)
 */
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

// Adapt to the layout: `src/`, or `frontend/src` + `backend/src`.
const UI = /^(src|frontend\/src)\/.*\.tsx$/;
const UI_TS = /^(src|frontend\/src)\/.*\.(ts|tsx)$/;
const SERVER = /^(src|backend\/src)\/.*\.ts$/;
// A file whose identifiers saved data keys off, so it must never be edited.
// Set it (e.g. /^src\/catalog\/index\.ts$/) or leave it matching nothing.
const NO_TOUCH = /^$/;
// The leader-lock call every scheduled job must make first when the service
// runs more than one worker.
const LEADER_LOCK = /\b(claimTick|withLeaderLock)\s*\(/;

const RULES = [
  // ── Web UI: the browser's own controls (keep when the project has its own) ──
  {
    id: 'native-select', files: UI, scope: 'file',
    line: (l) => /<(select|option)(\s|>|$)/.test(l), // `$`: a tag split across lines
    why: 'Native <select>/<option>. Use the project\'s Select component.',
  },
  {
    id: 'native-dialog', files: UI_TS, scope: 'file',
    // `confirm({ ... })` with an object is a project dialog, not the browser's.
    line: (l) => /\bwindow\.(confirm|alert|prompt)\s*\(|(?<![\w.$])(confirm|alert|prompt)\s*\(\s*[^{\s)]/.test(l),
    why: 'Browser confirm/alert/prompt. Use the project\'s confirm dialog or a toast.',
  },
  {
    id: 'native-date', files: UI, scope: 'file',
    line: (l) => /\btype=["'](date|datetime-local|time)["']/.test(l),
    why: 'Native date/time input opens the browser picker. Use the project\'s DatePicker / TimePicker.',
  },
  {
    id: 'native-tooltip', files: UI, scope: 'file',
    // Components that forward title= to the element they render count too; add them to the list.
    tag: (t) => (/^[a-z]/.test(t.name) || /^(Button|Link)$/.test(t.name)) && /\stitle=/.test(t.top),
    why: 'title= on an HTML element shows the browser tooltip. Use the project\'s Tooltip.',
  },
  {
    id: 'raw-hex', files: UI, scope: 'added',
    line: (l) => /\b(bg|text|border|from|via|to|fill|stroke|shadow|ring|outline|divide|decoration)(-[a-z]+)?-\[#[0-9a-fA-F]{3,8}\]/.test(l),
    why: 'Hard-coded hex colour. Use a theme token.',
  },
  // ── Server ──
  {
    id: 'cron-leader-lock', files: SERVER, scope: 'added',
    line: (l, src) => /\bcron\.schedule\s*\(/.test(l) && !LEADER_LOCK.test(src),
    why: 'cron.schedule in a file with no leader lock. With more than one worker the job runs once per worker. '
      + 'Claim the lock first.',
  },
  {
    id: 'no-touch', files: NO_TOUCH, scope: 'any',
    why: 'This file is a no-touch zone: saved data keys off its identifiers. Fix the data or lookup layer instead.',
  },
];

const unstaged = process.argv.includes('--unstaged');
const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));

const git = (args) => execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });

function content(file) {
  try {
    return unstaged ? readFileSync(file, 'utf8') : git(['show', `:${file}`]);
  } catch {
    return null; // deleted in this change
  }
}

/** Line numbers being added; null means every line (a new, untracked file). */
function addedLines(file) {
  let diff;
  try {
    diff = git(unstaged ? ['diff', 'HEAD', '-U0', '--', file] : ['diff', '--cached', '-U0', '--', file]);
  } catch {
    return null;
  }
  if (!diff && unstaged) {
    try { git(['ls-files', '--error-unmatch', '--', file]); } catch { return null; } // untracked
  }
  const lines = new Set();
  let cursor = 0;
  for (const line of diff.split('\n')) {
    const hunk = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (hunk) { cursor = Number(hunk[1]); continue; }
    if (line.startsWith('+') && !line.startsWith('+++')) lines.add(cursor++);
    else if (!line.startsWith('-')) cursor++;
  }
  return lines;
}

/**
 * JSX opening tags with their line span. `top` keeps only the characters at
 * brace depth 0, so an attribute inside a nested expression is not read as the
 * tag's own.
 */
function openingTags(src) {
  const tags = [];
  const re = /<([A-Za-z][\w.]*)/g;
  let m;
  while ((m = re.exec(src))) {
    let depth = 0, quote = null, top = '', i = re.lastIndex;
    const limit = Math.min(src.length, i + 4000);
    for (; i < limit; i++) {
      const c = src[i];
      if (quote) { if (c === quote && src[i - 1] !== '\\') quote = null; if (!depth) top += c; continue; }
      if (c === '"' || c === "'" || c === '`') { quote = c; if (!depth) top += c; continue; }
      if (c === '{') { depth++; continue; }
      if (c === '}') { depth--; continue; }
      if (c === '>' && depth === 0) break;
      if (!depth) top += c;
    }
    const start = src.slice(0, m.index).split('\n').length;
    const text = src.slice(m.index, i + 1);
    tags.push({ name: m[1], start, end: start + text.split('\n').length - 1, text, top });
  }
  return tags;
}

const isComment = (l) => /^\s*(\/\/|\*|\/\*|\{\s*\/\*)/.test(l);

const problems = [];
const escapes = [];

for (const file of files) {
  const rules = RULES.filter((r) => r.files.test(file) && !(r.exclude && r.exclude.test(file)));
  if (!rules.length) continue;
  const src = content(file);
  if (src === null) continue;
  const lines = src.split('\n');
  const added = addedLines(file);
  let tags;

  const escaped = (rule, first, last) => {
    for (let n = Math.max(1, first - 1); n <= last; n++) {
      const m = (lines[n - 1] || '').match(new RegExp(`gate-ok:\\s*${rule.id}\\b\\s*(.*?)\\s*(\\*\\/\\s*\\}?)?$`));
      if (m) {
        escapes.push({ file, line: n, rule: rule.id, reason: m[1] || '(no reason given)' });
        return true;
      }
    }
    return false;
  };
  const inScope = (rule, first, last) => {
    if (rule.scope !== 'added' || !added) return true;
    for (let n = first; n <= last; n++) if (added.has(n)) return true;
    return false;
  };
  const report = (rule, n, detail) => {
    problems.push({ rule, file, line: n, text: (detail || lines[n - 1].trim()).slice(0, 110) });
  };

  for (const rule of rules) {
    if (rule.scope === 'any') {
      if (!escaped(rule, 1, 1)) report(rule, 1, 'file is part of this change');
      continue;
    }
    if (rule.line) {
      lines.forEach((l, i) => {
        const n = i + 1;
        if (isComment(l) || !rule.line(l, src) || !inScope(rule, n, n) || escaped(rule, n, n)) return;
        report(rule, n);
      });
    }
    if (rule.tag) {
      tags ??= openingTags(src);
      for (const t of tags) {
        if (isComment(lines[t.start - 1]) || !rule.tag(t) || !inScope(rule, t.start, t.end) || escaped(rule, t.start, t.end)) continue;
        report(rule, t.start, rule.detail ? `<${t.name}> ${rule.detail(t)}` : undefined);
      }
    }
  }
}

if (escapes.length) {
  console.error('');
  console.error(`gate-ok escapes in this change (${escapes.length}), counted in the daily report:`);
  for (const e of escapes) console.error(`  ${e.file}:${e.line}  ${e.rule}  ${e.reason}`);
}

if (problems.length) {
  console.error('');
  console.error(`Blocked: ${problems.length} rule violation${problems.length === 1 ? '' : 's'} (rule gates)`);
  for (const rule of RULES) {
    const hits = problems.filter((p) => p.rule === rule);
    if (!hits.length) continue;
    console.error('');
    console.error(`[${rule.id}] ${rule.why}`);
    for (const p of hits) console.error(`  ${p.file}:${p.line}\n      ${p.text}`);
  }
  console.error('');
  console.error('Fix the code. Only if the owner approved this exception, mark the line:');
  console.error('  // gate-ok: <rule-id> <reason>        (in JSX: {/* gate-ok: <rule-id> <reason> */})');
  console.error('');
  process.exit(1);
}
