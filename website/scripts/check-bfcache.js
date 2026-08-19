// Regression check for what a back-navigation restores.
//
// The site links out (Footer's "Follow progress" → GitHub), and coming back
// lands on a bfcache restore: the browser thaws the document rather than
// re-running it. `load` never fires again, so anything torn down on the way
// out is gone for the rest of the session. That regression is invisible to a
// typecheck, a build, and even to check-scene-drag.js — it only appears on the
// second visit to the same document. Asserts, in order:
//   1. the phone stage mounts its WebGL scene on the first visit;
//   2. navigating away and back restores from bfcache at all (otherwise the
//      run is reported as SKIPPED, not as a pass);
//   3. the stage is still `.scene-active` with a live, un-lost WebGL context
//      — the shape of the "phone comes back blank" bug;
//   4. the restore does not block the main thread past RESTORE_TASK_BUDGET_MS;
//   5. the page logged no errors across the round trip.
//
// Usage: `npm run build && node scripts/check-bfcache.js`. Serves `dist/` on
// an ephemeral port for the duration of the run and closes it again — it never
// leaves a server holding a port behind.
import puppeteer from "puppeteer";
import { startDistServer } from "./lib/dist-server.js";
import { intersectionObserverDelivers, waitForSceneMount } from "./lib/scene-mount.js";

// Generous, because a CI runner renders this scene through software WebGL.
const SCENE_MOUNT_TIMEOUT_MS = 30_000;

// How long to keep watching for long tasks after `pageshow` fires. Covers the
// restore burst (ScrollTrigger.refresh, Lenis resync, any remount) without
// waiting on steady-state animation.
const RESTORE_WATCH_MS = 3_000;

// Longest single main-thread task the restore may spend before a visitor
// notices the page stop responding. Deliberately well above the 50ms
// "long task" definition: this is a freeze gate, not a jank gate, and a
// software-WebGL runner is slower than any real machine.
const RESTORE_TASK_BUDGET_MS = 500;

const STAGE = "[data-scene='phone']";

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
 * What the page-side probe below hangs off `window`. Declared here so the
 * `page.evaluate` callbacks — which this repo's type-aware ESLint config checks
 * against the DOM lib like any other source — can read it without every access
 * degrading to `any`.
 * @typedef {object} RestoreProbe
 * @property {{startTime: number, duration: number}[]} longTasks Every long task
 *   the page has performed, in order.
 * @property {number | null} restoredAt `performance.now()` at the bfcache
 *   restore, or null if the page was never restored from bfcache.
 * @typedef {Window & {sbRestoreProbe?: RestoreProbe}} ProbeWindow
 */

/**
 * Page-side probe, installed before any document script runs.
 *
 * Records every long task the page ever performs and the moment a bfcache
 * restore happened, so the runner can ask afterwards how much main-thread time
 * the restore itself cost. `buffered: true` backfills tasks that happened
 * before the observer was constructed; the `pageshow` listener survives the
 * freeze because bfcache restores JS state along with the DOM.
 */
function installRestoreProbe() {
  /** @type {RestoreProbe} */
  const state = { longTasks: [], restoredAt: null };
  /** @type {ProbeWindow} */ (window).sbRestoreProbe = state;
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      state.longTasks.push({ startTime: entry.startTime, duration: entry.duration });
    }
  }).observe({ type: "longtask", buffered: true });
  window.addEventListener("pageshow", (event) => {
    if (event.persisted) {
      state.restoredAt = performance.now();
    }
  });
}

const { server, port } = await startDistServer("check-bfcache");
const browser = await puppeteer.launch({
  headless: true,
  args: [
    // SwiftShader gives headless Chrome the WebGL2 context quality-gate.ts
    // probes for; without it the scene never mounts and there is nothing to
    // assert about its restore.
    "--enable-unsafe-swiftshader",
    "--no-sandbox",
    "--disable-dev-shm-usage",
    // bfcache is off by default for same-site navigations in some Chrome
    // configurations, and this run navigates between two pages of the same
    // site. Without this the restore is a fresh load and the check can only
    // report SKIPPED.
    "--enable-features=BackForwardCache:same_site_navigation_supported/true",
  ],
});

// Distinct from "passed": set when the runner cannot provide WebGL2 at all, or
// when its Chrome refuses to bfcache the page, in which case the behaviour
// under test cannot be exercised here. Reported loudly rather than dressed up
// as a pass.
let skipped = null;

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });
  await page.evaluateOnNewDocument(installRestoreProbe);

  const pageErrors = [];
  page.on("pageerror", (error) => {
    pageErrors.push(error.message);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      pageErrors.push(message.text());
    }
  });

  // `domcontentloaded`, deliberately not `networkidle0`: the page lazy-loads a
  // ~700kB three.js chunk as a scene comes into view, so "no connections for
  // 500ms" is not a readiness signal worth hanging on. The `.scene-active`
  // wait below is the real signal.
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
  await page.$eval(STAGE, (element) => {
    element.scrollIntoView({ block: "center" });
  });

  // Every scene mounts from an IntersectionObserver callback
  // (src/scripts/scenes/index.ts), so a runner that never delivers one can
  // never mount a scene. Reporting that as "the scene failed to mount, and
  // WebGL2 is available so this is real" would be a false accusation rather
  // than a finding, so the capability is established before the result is
  // trusted.
  const observerDelivers = await intersectionObserverDelivers(page);
  const sceneMounted =
    observerDelivers &&
    (await waitForSceneMount(page, `${STAGE}.scene-active canvas`, SCENE_MOUNT_TIMEOUT_MS));

  if (!observerDelivers) {
    skipped =
      "this Chrome never delivers IntersectionObserver callbacks, so no scene can mount here " +
      "and the scene behaviour cannot be exercised";
  } else if (sceneMounted) {
    expect(true, "phone stage mounts its WebGL scene on the first visit");
  } else {
    const hasWebgl2 = await page.evaluate(
      () => document.createElement("canvas").getContext("webgl2") !== null,
    );
    if (hasWebgl2) {
      expect(
        false,
        "phone stage mounts its WebGL scene (WebGL2 is available and it failed twice, so this is real)",
      );
      if (pageErrors.length > 0) {
        console.error(`  page errors: ${pageErrors.join("; ")}`);
      }
    } else {
      skipped =
        "this runner has no WebGL2 context, so the site correctly declines to mount the scene";
    }
  }

  if (sceneMounted) {
    // Same-origin stand-in for the real outbound link. What matters is that
    // the document is left and re-entered through history, not where it went;
    // hitting github.com from a check would make the suite depend on the
    // network and on a third party's uptime.
    await page.goto(`http://127.0.0.1:${port}/not-found/`, { waitUntil: "domcontentloaded" });
    await page.goBack({ waitUntil: "domcontentloaded" });

    const restoredAt = await page.evaluate(
      () => /** @type {ProbeWindow} */ (window).sbRestoreProbe?.restoredAt ?? null,
    );
    if (restoredAt === null) {
      skipped =
        "this Chrome did not restore the page from bfcache, so the restore path is not exercised";
    } else {
      expect(true, "back-navigation restores the page from bfcache");

      const stillLive = await page.$eval(STAGE, (element) => {
        const canvas = element.querySelector("canvas");
        if (!element.classList.contains("scene-active") || canvas === null) {
          return false;
        }
        // Re-requesting the context type the scene already created returns
        // that same context rather than a new one, so this reads the live
        // renderer's state instead of allocating anything.
        const context = canvas.getContext("webgl2");
        return context !== null && !context.isContextLost();
      });
      expect(stillLive, "phone stage survives the round trip with a live WebGL context");

      await new Promise((resolve) => {
        setTimeout(resolve, RESTORE_WATCH_MS);
      });
      const longestTaskMs = await page.evaluate((since) => {
        const tasks = /** @type {ProbeWindow} */ (window).sbRestoreProbe?.longTasks ?? [];
        return tasks
          .filter((task) => task.startTime >= since)
          .reduce((longest, task) => Math.max(longest, task.duration), 0);
      }, restoredAt);
      console.warn(`  info longest main-thread task after restore: ${Math.round(longestTaskMs)}ms`);
      expect(
        longestTaskMs <= RESTORE_TASK_BUDGET_MS,
        `restore blocks the main thread for at most ${RESTORE_TASK_BUDGET_MS}ms`,
      );

      expect(
        pageErrors.length === 0,
        `no page errors across the round trip${pageErrors.length > 0 ? `: ${pageErrors.join("; ")}` : ""}`,
      );
    }
  }
} finally {
  await browser.close();
  server.close();
}

if (skipped !== null) {
  console.warn(`check-bfcache: SKIPPED — ${skipped}. This is not a pass.`);
  process.exit(0);
}
if (failures.length > 0) {
  console.error(`check-bfcache: ${failures.length} failure(s).`);
  process.exit(1);
}
console.warn("check-bfcache: back-navigation restores the scenes it left mounted.");
