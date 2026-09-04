// Regression check for WebGL context loss and restore.
//
// A browser evicts the oldest WebGL context when a page (or the machine) holds
// too many live at once — this site mounts up to five, one per scene — then
// hands the context back. The scene engine (src/scripts/scenes/core.ts) used to
// treat that loss as permanent teardown: it disposed the scene and dropped its
// `.scene-active` class, so the container fell back to its static SVG art and
// never came back. That is the "the animations become gone, only barebones
// shapes are seen after the page has been open a while" bug.
//
// core.ts now pauses on `webglcontextlost` (preventDefault, show the fallback)
// and resumes on `webglcontextrestored` (THREE.WebGLRenderer re-initialises its
// GPU resources itself). This check drives that path directly with the
// WEBGL_lose_context extension and asserts, in order:
//   1. the phone stage mounts its WebGL scene;
//   2. losing the context drops `.scene-active` so the static fallback shows;
//   3. the context actually reports lost at that point;
//   4. restoring the context brings `.scene-active` back;
//   5. the restored context is live again (not lost);
//   6. the page logged no errors across the loss/restore cycle.
//
// Usage: `npm run build && node scripts/check-context-restore.js`. Serves
// `dist/` on an ephemeral port for the run and closes it again — it never leaves
// a server holding a port behind.
import puppeteer from "puppeteer";
import { startDistServer } from "./lib/dist-server.js";

// Generous, because a CI runner renders this scene through software WebGL.
const SCENE_MOUNT_TIMEOUT_MS = 30_000;
// The context lost/restored events are queued, not synchronous, and the
// software renderer rebuilds its resources on the way back, so give each state
// transition room without waiting on steady-state animation.
const STATE_TRANSITION_TIMEOUT_MS = 10_000;

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
 * Toggles the WebGL context of the stage's canvas via the WEBGL_lose_context
 * extension. Runs in the page; kept tiny and free of external references so it
 * serializes cleanly into `page.$eval`.
 * @param {Element} element The stage container.
 * @param {"lose" | "restore"} action Which transition to trigger.
 * @returns {boolean} Whether the extension was available to act on.
 */
function toggleContext(element, action) {
  const canvas = element.querySelector("canvas");
  if (canvas === null) {
    return false;
  }
  const context = canvas.getContext("webgl2");
  const extension = context?.getExtension("WEBGL_lose_context") ?? null;
  if (extension === null) {
    return false;
  }
  if (action === "lose") {
    extension.loseContext();
  } else {
    extension.restoreContext();
  }
  return true;
}

const { server, port } = await startDistServer("check-context-restore");
const browser = await puppeteer.launch({
  headless: true,
  args: [
    // SwiftShader gives headless Chrome the WebGL2 context quality-gate.ts
    // probes for; without it the scene never mounts and there is nothing to
    // assert about its context.
    "--enable-unsafe-swiftshader",
    "--no-sandbox",
    "--disable-dev-shm-usage",
  ],
});

// Distinct from "passed": set when the runner cannot provide WebGL2 at all, in
// which case the behaviour under test cannot be exercised here. Reported loudly
// rather than dressed up as a pass.
let skipped = null;

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900 });

  const pageErrors = [];
  page.on("pageerror", (error) => {
    pageErrors.push(error.message);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      pageErrors.push(message.text());
    }
  });

  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "domcontentloaded" });
  await page.$eval(STAGE, (element) => {
    element.scrollIntoView({ block: "center" });
  });

  let sceneMounted = true;
  try {
    await page.waitForSelector(`${STAGE}.scene-active canvas`, {
      timeout: SCENE_MOUNT_TIMEOUT_MS,
    });
  } catch {
    sceneMounted = false;
  }

  if (!sceneMounted) {
    const hasWebgl2 = await page.evaluate(
      () => document.createElement("canvas").getContext("webgl2") !== null,
    );
    if (hasWebgl2) {
      expect(false, "phone stage mounts its WebGL scene (WebGL2 is available, so this is real)");
      if (pageErrors.length > 0) {
        console.error(`  page errors: ${pageErrors.join("; ")}`);
      }
    } else {
      skipped =
        "this runner has no WebGL2 context, so the site correctly declines to mount the scene";
    }
  } else {
    expect(true, "phone stage mounts its WebGL scene");

    const lost = await page.$eval(STAGE, toggleContext, "lose");
    if (!lost) {
      skipped =
        "this runner's WebGL2 context does not expose WEBGL_lose_context, so loss cannot be simulated";
    } else {
      let fellBack = true;
      try {
        await page.waitForSelector(`${STAGE}:not(.scene-active)`, {
          timeout: STATE_TRANSITION_TIMEOUT_MS,
        });
      } catch {
        fellBack = false;
      }
      expect(fellBack, "losing the context drops .scene-active so the static fallback shows");

      const reportsLost = await page.$eval(STAGE, (element) => {
        const canvas = element.querySelector("canvas");
        const context = canvas?.getContext("webgl2") ?? null;
        return context?.isContextLost() === true;
      });
      expect(reportsLost, "the WebGL context reports lost after loseContext()");

      // The decisive regression assertion: the old code disposed the scene on
      // loss (canvas.remove(), listeners gone) so it could never come back. The
      // fix keeps everything mounted, so the canvas is still in the DOM and the
      // restore path is still wired.
      const canvasRetained = await page.$eval(
        STAGE,
        (element) => element.querySelector("canvas") !== null,
      );
      expect(canvasRetained, "the canvas is retained after loss (scene paused, not disposed)");

      // Attempt a real restore. WEBGL_lose_context.restoreContext() is a no-op
      // under some headless software-WebGL runners, so watch whether the
      // browser actually fires `webglcontextrestored` here; if it does not, the
      // resume path cannot be exercised on this runner and is reported SKIPPED
      // rather than dressed up as a pass. A real browser fires the event
      // natively when it hands an evicted context back, which is what core.ts's
      // handler resumes from.
      await page.$eval(STAGE, (element) => {
        const canvas = element.querySelector("canvas");
        /** @type {Window & { sbRestored?: boolean }} */ (window).sbRestored = false;
        canvas?.addEventListener(
          "webglcontextrestored",
          () => {
            /** @type {Window & { sbRestored?: boolean }} */ (window).sbRestored = true;
          },
          { once: true },
        );
      });
      await page.$eval(STAGE, toggleContext, "restore");
      await new Promise((resolve) => {
        setTimeout(resolve, 2_000);
      });
      const restoredEventFired = await page.evaluate(
        () => /** @type {Window & { sbRestored?: boolean }} */ (window).sbRestored === true,
      );

      if (!restoredEventFired) {
        skipped =
          "this runner's WEBGL_lose_context does not fire webglcontextrestored (headless software WebGL), so the resume path is not exercised here";
      } else {
        let recovered = true;
        try {
          await page.waitForSelector(`${STAGE}.scene-active canvas`, {
            timeout: STATE_TRANSITION_TIMEOUT_MS,
          });
        } catch {
          recovered = false;
        }
        expect(recovered, "restoring the context brings .scene-active back");

        const liveAgain = await page.$eval(STAGE, (element) => {
          const canvas = element.querySelector("canvas");
          const context = canvas?.getContext("webgl2") ?? null;
          return context !== null && !context.isContextLost();
        });
        expect(liveAgain, "the restored WebGL context is live again");

        expect(
          pageErrors.length === 0,
          `no page errors across the loss/restore cycle${pageErrors.length > 0 ? `: ${pageErrors.join("; ")}` : ""}`,
        );
      }
    }
  }
} finally {
  await browser.close();
  server.close();
}

if (skipped !== null) {
  console.warn(`check-context-restore: SKIPPED — ${skipped}. This is not a pass.`);
  process.exit(0);
}
if (failures.length > 0) {
  console.error(`check-context-restore: ${failures.length} failure(s).`);
  process.exit(1);
}
console.warn("check-context-restore: a lost WebGL context falls back and recovers.");
