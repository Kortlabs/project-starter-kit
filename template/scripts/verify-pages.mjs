#!/usr/bin/env node
// Visit the real pages in a real browser, screenshot each one, and fail on
// anything the server cannot tell you about: a mount-time exception, a failed
// request, a hidden 401, a layout that overflows.
//
// The point is that HTTP 200 proves almost nothing. A page can return 200 and
// throw on hydrate, and only a browser notices.
//
//   node scripts/verify-pages.mjs
//   node scripts/verify-pages.mjs --base https://staging.example.com --pages /,/pricing
//
// Screenshots land in .playwright-output/ and can be opened, or read directly
// by an assistant.

import { chromium } from "playwright";
import { mkdirSync } from "node:fs";

const arg = (name, fallback) => {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split("=").slice(1).join("=") : fallback;
};

const BASE = arg("base", process.env.VERIFY_BASE_URL ?? "http://localhost:3000");
const PAGES = arg("pages", "/").split(",").map((p) => p.trim()).filter(Boolean);
const OUT = ".playwright-output";
const WIDTHS = arg("widths", "1280,375").split(",").map(Number);

// Console noise that is never actionable. Keep this list short and justified —
// every entry is a class of error you have decided to stop seeing.
const IGNORE = [/favicon/i, /Download the React DevTools/i];

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
let failures = 0;

for (const width of WIDTHS) {
  const context = await browser.newContext({ viewport: { width, height: 900 } });

  // If the app needs a session, sign in once here and reuse the context.
  // Credentials belong in a gitignored env file, never in this script.
  //   const page = await context.newPage();
  //   await page.goto(`${BASE}/login`);
  //   await page.fill('input[name=email]', process.env.E2E_EMAIL);
  //   ...

  for (const path of PAGES) {
    const page = await context.newPage();
    const problems = [];
    page.on("pageerror", (e) => problems.push(`uncaught: ${e.message.slice(0, 160)}`));
    page.on("console", (m) => {
      if (m.type() !== "error") return;
      const text = m.text();
      if (!IGNORE.some((re) => re.test(text))) problems.push(`console: ${text.slice(0, 160)}`);
    });
    page.on("requestfailed", (r) => problems.push(`request failed: ${r.url().slice(0, 120)}`));

    const res = await page.goto(BASE + path, { waitUntil: "networkidle", timeout: 45000 }).catch((e) => {
      problems.push(`navigation: ${e.message.slice(0, 120)}`);
      return null;
    });
    await page.waitForTimeout(600);

    const status = res?.status() ?? 0;
    if (status >= 400) problems.push(`HTTP ${status}`);

    // A page wider than its viewport is a layout bug on every phone.
    const overflows = await page
      .evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1)
      .catch(() => false);
    if (overflows) problems.push("horizontal overflow");

    const name = `${(path === "/" ? "home" : path.replace(/\W+/g, "-").replace(/^-|-$/g, ""))}-${width}`;
    await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true }).catch(() => {});

    if (problems.length) {
      failures++;
      console.log(`FAIL  ${width}px  ${path}`);
      for (const p of problems) console.log(`        ${p}`);
    } else {
      console.log(`ok    ${width}px  ${path}  (${status})`);
    }
    await page.close();
  }
  await context.close();
}

await browser.close();
console.log(`\n${failures ? `${failures} page(s) with problems` : "all pages clean"} — screenshots in ${OUT}/`);
process.exit(failures ? 1 : 0);
