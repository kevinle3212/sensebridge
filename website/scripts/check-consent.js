// Gate for the error-monitoring consent mechanism (src/scripts/monitoring-consent.ts,
// src/components/MonitoringConsent.astro).
//
// The claim this site makes on /privacy is not "we only send data with your
// consent" — it is the stronger one that without consent, the code that could
// send it is never downloaded. That is a claim about network requests, and a
// typecheck, a lint, or a build cannot prove it. So this drives a real browser
// over the built site and watches what it actually fetches. Asserts, in order:
//
//   1. a visitor who has never answered downloads no Sentry chunk at all;
//   2. nothing is written to `localStorage` before they answer;
//   3. the switch is exposed to assistive tech as an off switch;
//   4. turning it on fetches the SDK chunk and records the consent;
//   5. turning it back off records the withdrawal;
//   6. a browser sending Global Privacy Control gets no switch, and fetches
//      nothing, even with a granted consent already in storage;
//   7. the page logged no errors through any of it.
//
// Usage: `npm run build && node scripts/check-consent.js`. Serves `dist/` on an
// ephemeral port for the duration of the run and closes it again — it never
// leaves a server holding a port behind.
//
// Requires a build made with PUBLIC_SENTRY_DSN set, because without one the
// integration is never registered and there is no control to exercise. The run
// SKIPS rather than fails in that case: an unconfigured build is a valid state
// of this repository, and it is the default one.
import puppeteer from "puppeteer";
import { startDistServer } from "./lib/dist-server.js";

/** How long to wait for the lazily imported SDK chunk after opting in. */
const CHUNK_FETCH_TIMEOUT_MS = 10_000;

/** Must match MONITORING_CONSENT_KEY in src/scripts/monitoring-consent.ts. */
const CONSENT_KEY = "sensebridge.monitoring-consent";

const failures = [];

/**
 * Records a failure instead of throwing, so one run reports every problem.
 * @param {boolean} condition Assertion that must hold.
 * @param {string} message What the assertion was checking.
 */
function expect(condition, message) {
  if (condition) {
    console.warn(`  ok   ${message}`);
  } else {
    failures.push(message);
    console.warn(`  FAIL ${message}`);
  }
}

/**
 * Whether `url` is the lazily imported chunk that carries the Sentry SDK.
 *
 * Matched on the chunk name rather than the hash, which changes every build.
 * Vite names a dynamic-import chunk after its entry module, so this tracks
 * `src/scripts/monitoring.ts` by construction.
 *
 * @param {string} url Request URL.
 * @returns {boolean} True for the monitoring chunk, false for anything else —
 *   including `monitoring-consent`, which is the eager bootstrap and is
 *   supposed to load.
 */
function isSentryChunk(url) {
  return /\/monitoring\.[^/]*\.js$/.test(url);
}

/**
 * Waits for a Sentry chunk request, or gives up.
 * @param {string[]} requested URLs seen so far, appended to by the page.
 * @returns {Promise<boolean>} True if the chunk was fetched in time.
 */
async function waitForSentryChunk(requested) {
  const deadline = Date.now() + CHUNK_FETCH_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (requested.some(isSentryChunk)) {
      return true;
    }
    await new Promise((resolve) => {
      setTimeout(resolve, 50);
    });
  }
  return false;
}

const { server, port } = await startDistServer("check-consent");
const browser = await puppeteer.launch({ headless: true });
let skipped = false;

try {
  const page = await browser.newPage();
  /** @type {string[]} */
  const pageErrors = [];
  page.on("pageerror", (/** @type {Error} */ error) => pageErrors.push(error.message));

  /** @type {string[]} */
  let requested = [];
  page.on("request", (request) => requested.push(request.url()));

  await page.goto(`http://127.0.0.1:${port}/privacy/`, { waitUntil: "networkidle0" });

  const control = await page.$("[data-monitoring-toggle]");
  if (!control) {
    skipped = true;
  } else {
    expect(
      !requested.some(isSentryChunk),
      "a visitor who has not answered fetches no Sentry chunk",
    );
    const storedBefore = await page.evaluate(
      (key) => window.localStorage.getItem(key),
      CONSENT_KEY,
    );
    expect(storedBefore === null, "nothing is written to storage before the visitor answers");

    // Read `hidden` as an attribute rather than as the `HTMLElement` property:
    // `$eval` types its argument as `Element`, which has no such property. The
    // two agree, because `hidden` is a reflected attribute and the component
    // reveals the switch by assigning the property.
    const before = await page.$eval("[data-monitoring-toggle]", (element) => ({
      role: element.getAttribute("role"),
      checked: element.getAttribute("aria-checked"),
      hidden: element.hasAttribute("hidden"),
      name: element.textContent.trim(),
    }));
    expect(before.role === "switch", "the control is exposed as a switch");
    expect(before.checked === "false", "the switch starts off");
    expect(!before.hidden, "the switch is revealed once its script has run");
    expect(before.name.length > 0, "the switch has a non-empty accessible name");

    // Opt in.
    requested = [];
    await page.click("[data-monitoring-toggle]");
    expect(await waitForSentryChunk(requested), "opting in fetches the Sentry chunk");
    const storedAfterOptIn = await page.evaluate(
      (key) => window.localStorage.getItem(key),
      CONSENT_KEY,
    );
    expect(storedAfterOptIn === "granted", "opting in records consent");
    const checkedAfterOptIn = await page.$eval("[data-monitoring-toggle]", (element) =>
      element.getAttribute("aria-checked"),
    );
    expect(checkedAfterOptIn === "true", "the switch reflects that it is on");

    // Opt back out.
    await page.click("[data-monitoring-toggle]");
    const storedAfterOptOut = await page.evaluate(
      (key) => window.localStorage.getItem(key),
      CONSENT_KEY,
    );
    expect(storedAfterOptOut === "denied", "opting back out records the withdrawal");

    // Global Privacy Control outranks a stored consent. Set storage to
    // "granted" first, so this proves an override rather than merely a default.
    const gpcPage = await browser.newPage();
    const gpcRequested = [];
    gpcPage.on("request", (request) => gpcRequested.push(request.url()));
    gpcPage.on("pageerror", (/** @type {Error} */ error) => pageErrors.push(error.message));
    await gpcPage.evaluateOnNewDocument((key) => {
      Object.defineProperty(navigator, "globalPrivacyControl", { get: () => true });
      window.localStorage.setItem(key, "granted");
    }, CONSENT_KEY);
    await gpcPage.goto(`http://127.0.0.1:${port}/privacy/`, { waitUntil: "networkidle0" });
    expect(
      !gpcRequested.some(isSentryChunk),
      "a Global Privacy Control signal overrides a stored consent — no chunk is fetched",
    );
    const gpcVisibility = await gpcPage.$eval("[data-monitoring-toggle]", (element) =>
      element.hasAttribute("hidden") ? "hidden" : "visible",
    );
    expect(gpcVisibility === "hidden", "no switch is offered under Global Privacy Control");
    const gpcNoteShown = await gpcPage.$eval(
      "[data-monitoring-gpc]",
      (element) => !element.hasAttribute("hidden") && element.textContent.trim().length > 0,
    );
    expect(gpcNoteShown, "the page explains why the switch is absent");
    await gpcPage.close();

    expect(pageErrors.length === 0, `no page errors throughout: ${pageErrors.join("; ")}`);
  }
} finally {
  await browser.close();
  server.close();
}

if (skipped) {
  console.warn(
    "check-consent: SKIPPED — this build has no PUBLIC_SENTRY_DSN, so no consent " +
      "control is rendered and there is nothing to exercise. Rebuild with the " +
      "variable set to run this. This is not a pass.",
  );
  process.exit(0);
}
if (failures.length > 0) {
  console.error(`check-consent: ${failures.length} failure(s).`);
  process.exit(1);
}
console.warn("check-consent: monitoring stays off, and off means never downloaded.");
