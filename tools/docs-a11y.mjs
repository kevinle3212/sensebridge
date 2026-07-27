#!/usr/bin/env node
/**
 * Accessibility gate for the built `docs/` GitHub Pages site.
 *
 * Runs two passes over every built page:
 *
 *  1. pa11y at WCAG 2.2 AA, once per theme. The theme is written to
 *     `localStorage` before first paint, which also exercises the layout's
 *     pre-paint script. This is why the gate does not use a `.pa11yci.json`:
 *     that config's `wait for element` action watches for *node insertion*,
 *     and the theme is an attribute flip on `<html>`, so every page would time
 *     out on a defect that does not exist.
 *  2. Checks pa11y does not cover, read from Chrome's own accessibility tree:
 *     an accessible name on every interactive element (the repo's hard gate,
 *     per docs/ACCESSIBILITY.md), skip link first in tab order, no positive
 *     `tabindex`, no duplicate ids, one `<h1>` per page, a `lang`, no
 *     animation under `prefers-reduced-motion`, and no uncaught page errors.
 *
 * The page-error check is the reason this exists as a gate rather than a
 * one-off: `docs/assets/js/docs.js` ships unbundled, so a syntax error in it
 * disables every interactive feature on the site while the Jekyll build stays
 * green. `ci.yml` also runs `node --check` on that file; this catches runtime
 * failures that parsing cannot.
 *
 * Usage: node tools/docs-a11y.mjs <built-site-dir>
 *
 * Requires `pa11y` and `puppeteer` on the module path; CI installs them with
 * `npm install --no-save pa11y puppeteer`.
 */

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PORT = 4399;
const THEMES = ["dark", "light"];
const NAMED_ROLES = new Set([
  "button",
  "link",
  "textbox",
  "checkbox",
  "radio",
  "combobox",
  "searchbox",
]);
const CONTENT_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".woff2": "font/woff2",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".txt": "text/plain; charset=utf-8",
};

/**
 * Reads `baseurl` out of `docs/_config.yml`.
 *
 * The built site references assets by absolute path (`/sensebridge/assets/…`),
 * so the local server has to mount the site under the same prefix or every
 * stylesheet and script 404s and the run reports phantom failures.
 *
 * @returns {string} The base path, without a trailing slash (may be empty).
 */
function readBaseUrl() {
  const config = fs.readFileSync(path.join(REPO_ROOT, "docs/_config.yml"), "utf8");
  const match = config.match(/^baseurl:\s*(\S+)\s*$/m);
  return match ? match[1].replace(/\/$/, "") : "";
}

/**
 * Serves a built site directory under `basePath` on localhost.
 *
 * @param {string} siteDir Directory holding the built site.
 * @param {string} basePath Path prefix to mount it under.
 * @returns {Promise<http.Server>} The listening server.
 */
function serve(siteDir, basePath) {
  const server = http.createServer((req, res) => {
    let rel = decodeURIComponent(req.url.split("?")[0]);
    if (basePath && rel.startsWith(basePath)) rel = rel.slice(basePath.length);
    if (rel.endsWith("/")) rel += "index.html";
    const target = path.join(siteDir, path.normalize(rel).replace(/^(\.\.[/\\])+/, ""));
    fs.readFile(target, (err, body) => {
      if (err) {
        res.writeHead(404).end("not found");
        return;
      }
      res.writeHead(200, { "content-type": CONTENT_TYPES[path.extname(target)] || "application/octet-stream" });
      res.end(body);
    });
  });
  return new Promise((resolve) => server.listen(PORT, "127.0.0.1", () => resolve(server)));
}

/**
 * Runs pa11y over every page in one theme.
 *
 * @param {object} browser Puppeteer browser instance.
 * @param {Function} pa11y The pa11y entry point.
 * @param {string[]} urls Page URLs to test.
 * @param {string} theme Either "dark" or "light".
 * @returns {Promise<string[]>} Human-readable failures; empty means clean.
 */
async function runPa11y(browser, pa11y, urls, theme) {
  const failures = [];
  for (const url of urls) {
    const page = await browser.newPage();
    await page.evaluateOnNewDocument((value) => {
      try {
        localStorage.setItem("sb-theme", value);
      } catch (e) {
        /* storage disabled; the CSS media-query fallback still applies */
      }
    }, theme);
    await page.emulateMediaFeatures([
      { name: "prefers-color-scheme", value: theme },
      { name: "prefers-reduced-motion", value: "reduce" },
    ]);
    const result = await pa11y(url, { browser, page, standard: "WCAG2AA", timeout: 60000 });
    const applied = await page.evaluate(() => document.documentElement.getAttribute("data-theme"));
    if (applied !== theme) failures.push(`${url} [${theme}]: theme not applied (got ${applied})`);
    for (const issue of result.issues) {
      failures.push(`${url} [${theme}]: ${issue.code}\n    ${issue.message}\n    ${issue.selector}`);
    }
    await page.close();
  }
  return failures;
}

/**
 * Runs the structural checks pa11y does not cover.
 *
 * @param {object} browser Puppeteer browser instance.
 * @param {string[]} urls Page URLs to test.
 * @returns {Promise<{failures: string[], interactive: number}>} Failures plus
 *   the number of interactive elements whose accessible name was verified.
 */
async function runStructural(browser, urls) {
  const failures = [];
  let interactive = 0;

  for (const url of urls) {
    const page = await browser.newPage();
    const pageErrors = [];
    page.on("pageerror", (error) => pageErrors.push(String(error.message)));
    await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
    await page.goto(url, { waitUntil: "networkidle0" });

    const unnamed = [];
    const snapshot = await page.accessibility.snapshot({ interestingOnly: false });
    (function walk(node) {
      if (!node) return;
      if (NAMED_ROLES.has(node.role)) {
        interactive += 1;
        if (!node.name || !node.name.trim()) unnamed.push(node.role);
      }
      (node.children || []).forEach(walk);
    })(snapshot);

    const dom = await page.evaluate(() => {
      const focusable = [
        ...document.querySelectorAll(
          'a[href],button,input,select,textarea,summary,[tabindex]:not([tabindex="-1"])'
        ),
      ];
      const animating = [...document.querySelectorAll("*")]
        .filter((el) => {
          const style = getComputedStyle(el);
          return (
            (style.animationName !== "none" && parseFloat(style.animationDuration) > 0.01) ||
            parseFloat(style.transitionDuration) > 0.01
          );
        })
        .map((el) => el.className || el.tagName);
      const seen = new Set();
      const duplicateIds = [];
      document.querySelectorAll("[id]").forEach((el) => {
        if (seen.has(el.id)) duplicateIds.push(el.id);
        seen.add(el.id);
      });
      return {
        first: focusable[0]?.className || focusable[0]?.tagName || "(none)",
        positiveTabindex: focusable.filter((el) => Number(el.getAttribute("tabindex")) > 0).length,
        animating,
        duplicateIds,
        lang: document.documentElement.lang,
        h1Count: document.querySelectorAll("main h1").length,
      };
    });

    const issues = [];
    if (pageErrors.length) issues.push(`uncaught page error: ${pageErrors.join("; ")}`);
    if (unnamed.length) issues.push(`interactive elements with no accessible name: ${unnamed.join(", ")}`);
    if (dom.positiveTabindex) issues.push(`positive tabindex on ${dom.positiveTabindex} element(s)`);
    if (!String(dom.first).includes("skip-link")) issues.push(`first focusable element is ${dom.first}, not the skip link`);
    if (dom.animating.length) issues.push(`animates under prefers-reduced-motion: ${dom.animating.join(", ")}`);
    if (dom.h1Count !== 1) issues.push(`${dom.h1Count} <h1> in <main>, expected exactly 1`);
    if (dom.duplicateIds.length) issues.push(`duplicate ids: ${dom.duplicateIds.join(", ")}`);
    if (!dom.lang) issues.push("<html> has no lang attribute");
    if (issues.length) failures.push(`${url}\n    - ${issues.join("\n    - ")}`);

    await page.close();
  }
  return { failures, interactive };
}

const siteDir = path.resolve(process.argv[2] || "tmp/_site");
if (!fs.existsSync(siteDir)) {
  console.error(`No built site at ${siteDir}. Build docs/ first.`);
  process.exit(2);
}

const { default: pa11y } = await import("pa11y");
const { default: puppeteer } = await import("puppeteer");

const basePath = readBaseUrl();
const server = await serve(siteDir, basePath);
const pages = fs.readdirSync(siteDir).filter((f) => f.endsWith(".html")).sort();
const urls = pages.map(
  (f) => `http://127.0.0.1:${PORT}${basePath}/${f === "index.html" ? "" : f}`
);

const browser = await puppeteer.launch({
  args: ["--no-sandbox", "--disable-dev-shm-usage", "--enable-unsafe-swiftshader"],
});

const failures = [];
for (const theme of THEMES) {
  failures.push(...(await runPa11y(browser, pa11y, urls, theme)));
}
const structural = await runStructural(browser, urls);
failures.push(...structural.failures);

await browser.close();
server.close();

console.log(`Pages checked: ${pages.length} (themes: ${THEMES.join(", ")})`);
console.log(`Interactive elements with a verified accessible name: ${structural.interactive}`);
if (failures.length) {
  console.error(`\n${failures.length} accessibility failure(s):\n`);
  for (const failure of failures) console.error(`  ${failure}\n`);
  process.exit(1);
}
console.log("All checks passed.");
