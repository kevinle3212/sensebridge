#!/usr/bin/env node
/**
 * Screenshot the contact sheet and each in-situ mockup.
 *
 * This is the escalation of "look at the logo and tell me if it's right" into a
 * command: it renders the real page in headless Chrome, fails loudly on any
 * console error or unresolved image, and writes PNGs that can be diffed on a
 * later run.
 */

const path = require("path");
const fs = require("fs");

// See the note in build-raster.js: resolved from this file, not hardcoded.
const REPO_ROOT = path.resolve(__dirname, "..", "..");
const puppeteer = require(path.join(REPO_ROOT, "website", "node_modules", "puppeteer"));

const ROOT = __dirname;
const OUT = path.join(ROOT, "preview");
fs.mkdirSync(OUT, { recursive: true });

/** Mockup element ids to capture individually, with the viewport each needs. */
const SHOTS = [
  ["mock-browser-tab", "applied-browser-tab"],
  ["mock-navbar-dark", "applied-navbar-dark"],
  ["mock-navbar-light", "applied-navbar-light"],
  ["mock-avatar", "applied-github-avatar"],
  ["mock-avatar-light", "applied-github-avatar-light"],
  ["mock-appicon", "applied-app-icon"],
];

(async () => {
  const browser = await puppeteer.launch({ headless: "new", args: ["--font-render-hinting=none"] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 1000, deviceScaleFactor: 2 });

  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("requestfailed", (r) => errors.push(`request failed: ${r.url()}`));

  await page.goto(`file://${path.join(ROOT, "index.html")}`, { waitUntil: "networkidle0" });
  await page.evaluate(() => document.fonts.ready);
  // Lazy-loaded tiles only decode once scrolled past, so walk the page first.
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 500) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 60));
    }
    window.scrollTo(0, 0);
  });
  await new Promise((r) => setTimeout(r, 600));

  // Assert every image actually decoded, not just that the file existed.
  const broken = await page.evaluate(() =>
    [...document.images].filter((i) => !i.complete || i.naturalWidth === 0).map((i) => i.getAttribute("src")));

  await page.screenshot({ path: path.join(OUT, "contact-sheet-full.png"), fullPage: true });

  for (const [id, name] of SHOTS) {
    const el = await page.$(`#${id}`);
    if (!el) { errors.push(`missing mockup #${id}`); continue; }
    await el.screenshot({ path: path.join(OUT, `${name}.png`) });
  }

  await browser.close();

  console.log(`broken images: ${broken.length}`);
  broken.forEach((b) => console.log("  ", b));
  console.log(`console/request errors: ${errors.length}`);
  errors.slice(0, 10).forEach((e) => console.log("  ", e));
  console.log(`previews written to ${path.relative(process.cwd(), OUT)}`);

  if (broken.length || errors.length) process.exit(1);
})();
