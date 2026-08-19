// Waiting for a WebGL stage to mount, with one retry — shared by the puppeteer
// smoke checks (scripts/check-scene-drag.js, scripts/check-bfcache.js).
//
// Why a retry exists at all. Both checks wait 30s for `.scene-active canvas`
// and, on timeout, report a hard failure whose message asserts the regression
// is genuine because WebGL2 is available. Under real machine load that
// assertion was wrong: the checks were observed failing while an `xcodebuild`
// simulator run was saturating the machine, and passing on the same commit
// on an idle one. A scene that needs a few more seconds under load is not the
// same defect as a scene that never mounts, and reporting them identically
// trains everyone to disbelieve the check.
//
// Why exactly one retry, and why only on a timeout. One retry distinguishes
// "slow" from "broken" — which is the whole question — without becoming a
// polling loop that hides a genuine regression behind a long enough wait. And
// a timeout is the only failure worth retrying: a page crash, a closed target,
// or a protocol error will not fix itself on a second wait, so those rethrow
// immediately rather than paying another 30s to report the same thing.
//
// Extracted rather than duplicated so the two checks can never drift into
// disagreeing about what "mounted" means.

/**
 * Waits for `selector`, retrying once if the first wait times out.
 *
 * @param {import("puppeteer").Page} page Page to wait on.
 * @param {string} selector Selector that appears once the scene has mounted.
 * @param {number} timeoutMs Per-attempt timeout; the total budget is twice this.
 * @returns {Promise<boolean>} True once mounted, false if both attempts timed out.
 * @throws Rethrows any non-timeout error, which a retry could not fix.
 */
export async function waitForSceneMount(page, selector, timeoutMs) {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      await page.waitForSelector(selector, { timeout: timeoutMs });
      return true;
    } catch (error) {
      // Puppeteer names its timeout `TimeoutError`; anything else is a real
      // fault and must surface as itself rather than as "the scene is missing".
      if (error?.name !== "TimeoutError") {
        throw error;
      }
      if (attempt === 0) {
        console.warn(
          `  scene did not mount within ${timeoutMs}ms — retrying once before failing ` +
            "(a loaded machine is the common cause; a real regression fails both attempts)",
        );
      }
    }
  }
  return false;
}

/**
 * Whether this browser actually delivers `IntersectionObserver` callbacks.
 *
 * Not a feature-detect — `"IntersectionObserver" in window` is true in every
 * Chrome, including ones that never deliver a single entry. This observes a
 * real, laid-out element and waits for a callback that should be immediate.
 *
 * It exists because every "First Light" scene mounts from an
 * IntersectionObserver callback (src/scripts/scenes/index.ts), so a runner
 * that never fires one can never mount a scene — and both scene checks would
 * then report "the scene failed to mount, and WebGL2 is available so this is
 * real", which is a false accusation rather than a finding. Measured
 * 2026-08-18 against the pinned Chrome: callbacks never arrive in headless,
 * even for a 300x300 visible div with no scrolling involved.
 *
 * @param {import("puppeteer").Page} page Page to probe. Any loaded page works.
 * @param {number} timeoutMs How long to wait for the callback before giving up.
 * @returns {Promise<boolean>} True if a callback arrived.
 */
export async function intersectionObserverDelivers(page, timeoutMs = 4000) {
  /** @type {boolean} */
  const delivered = await page.evaluate(async (limit) => {
    const probe = document.createElement("div");
    probe.style.cssText =
      "position:fixed;top:0;left:0;width:300px;height:300px;pointer-events:none";
    document.body.append(probe);
    try {
      /** @type {boolean} */
      const result = await new Promise((resolve) => {
        const timer = setTimeout(() => {
          resolve(false);
        }, limit);
        const observer = new IntersectionObserver(() => {
          clearTimeout(timer);
          observer.disconnect();
          resolve(true);
        });
        observer.observe(probe);
      });
      return result;
    } finally {
      probe.remove();
    }
  }, timeoutMs);
  return delivered;
}
