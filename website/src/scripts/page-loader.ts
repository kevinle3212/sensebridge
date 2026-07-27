// Driver for the "Span the gap" page-load sequence. The overlay and its whole
// visual state machine live in src/components/PageLoader.astro; the decision
// to run at all, and the fail-open watchdog, live in public/page-load.js. This
// file is the middle piece: it turns real load milestones into the single
// `--page-build` number the stylesheet reads, then owns the unlock, the skip
// control, and the exit transition.
//
// Loaded eagerly from BaseLayout.astro rather than at idle like motion.ts and
// the 3D scenes: those decorate a page that is already usable, while this one
// is currently covering it. It carries no dependency for that reason — no
// GSAP, no Lenis. Pulling ~70kB of animation library into the critical path to
// animate a loading screen would be the loading screen making the load slower.
import { debugLog } from "./debug";

export {};

/**
 * Shortest the build may take, in ms.
 *
 * On a warm cache a page can be fully loaded in well under 100ms, and a
 * bridge that snaps from nothing to built in three frames reads as a glitch
 * rather than as a sequence. This is the one place where the progress bar is
 * paced by something other than the page: the number still only ever reports
 * real milestones, but it is not allowed to climb faster than this floor.
 */
const MIN_BUILD_MS = 900;

/**
 * How long the unlock runs before the overlay is hidden again.
 *
 * Mirrors `$reveal-duration` in PageLoader.astro, which is the sum of the
 * panels' delay and their duration. Retune both together.
 */
const REVEAL_MS = 880;

/**
 * How long the exit transition runs before the browser navigates.
 *
 * Mirrors `$close-duration` in PageLoader.astro. Every ms here is added to
 * a real navigation the visitor asked for, so it is deliberately the shortest
 * of the three constants.
 */
const CLOSE_MS = 420;

/**
 * Progress ceilings for the three load milestones the browser actually
 * reports. Between two of them the bar eases toward the next ceiling without
 * reaching it, so it is always truthful about being unfinished, and it only
 * ever hits 1 once `load` has genuinely fired.
 *
 * This is the honest half of the feature: nothing here is a timer pretending
 * to be progress. The one concession is MIN_BUILD_MS above, which can slow the
 * bar down but never speed it up or move it past a milestone that has not
 * happened.
 */
const MILESTONE = { parsed: 0.4, fonts: 0.7, loaded: 1 };

const root = document.documentElement;
const loader = document.querySelector<HTMLElement>("[data-page-loader]");
const count = document.querySelector<HTMLElement>("[data-page-load-count]");

// Nothing to drive: no overlay on the page, or public/page-load.js declined to
// run it (reduced motion, or JS that never got that far). The exit transition
// is skipped too — it is the same decoration under a different name, and a
// reduced-motion visitor opted out of both.
if (loader && count && root.dataset.pageLoad === "building") {
  runBuild(loader, count);
  initExitTransition();
  initBfcacheReset();
}

/**
 * Runs the build: eases `--page-build` toward whichever milestone has been
 * reached, writing it and the percentage once per frame until it lands on 1.
 *
 * @param element - The overlay, which owns the `--page-build` property.
 * @param readout - The element whose text is the percentage.
 */
function runBuild(element: HTMLElement, readout: HTMLElement): void {
  const startedAt = performance.now();
  // The ceiling, raised by each milestone as it resolves. `shown` chases it
  // and is what actually reaches the screen.
  let ceiling = 0.12;
  let shown = 0;
  let finished = false;

  const reach = (value: number): void => {
    ceiling = Math.max(ceiling, value);
    debugLog("page-loader", "milestone reached:", value);
  };

  if (document.readyState === "loading") {
    document.addEventListener(
      "DOMContentLoaded",
      () => {
        reach(MILESTONE.parsed);
      },
      { once: true },
    );
  } else {
    reach(MILESTONE.parsed);
  }
  // Fonts matter here specifically: three self-hosted variable faces are
  // preloaded in BaseLayout.astro, and revealing the page mid-swap is the one
  // visible reflow this sequence is in a position to hide.
  void document.fonts.ready.then(() => {
    reach(MILESTONE.fonts);
  });
  if (document.readyState === "complete") {
    reach(MILESTONE.loaded);
  } else {
    window.addEventListener(
      "load",
      () => {
        reach(MILESTONE.loaded);
      },
      { once: true },
    );
  }

  const finish = (): void => {
    if (finished) {
      return;
    }
    finished = true;
    element.style.setProperty("--page-build", "1");
    readout.textContent = "100%";
    root.dataset.pageLoad = "open";
    debugLog("page-loader", "unlocked after", Math.round(performance.now() - startedAt), "ms");
    window.setTimeout(() => {
      // Back to `display: none` (PageLoader.astro's resting state), which stops
      // every animation on the overlay dead. The node itself stays in the
      // document so the exit transition can reuse it.
      root.removeAttribute("data-page-load");
    }, REVEAL_MS);
  };

  const frame = (now: number): void => {
    if (finished) {
      return;
    }
    // Asymptotic chase, so the bar decelerates into each milestone instead of
    // stopping dead on it, and can never overshoot one.
    shown += (ceiling - shown) * 0.09;
    // The floor from MIN_BUILD_MS. Applied as a cap rather than as a separate
    // timeline so the bar stays monotonic either way.
    shown = Math.min(shown, (now - startedAt) / MIN_BUILD_MS);

    element.style.setProperty("--page-build", shown.toFixed(4));
    readout.textContent = `${Math.round(shown * 100)}%`;

    if (ceiling >= 1 && shown > 0.995) {
      finish();
      return;
    }
    requestAnimationFrame(frame);
  };

  requestAnimationFrame(frame);

  // Skip control. Anyone who clicks or types has told us they would rather
  // have the page than the animation, and the overlay is covering the page, so
  // that is the only reading. Keyboard is listened for on the window because
  // the overlay itself holds no focus.
  element.addEventListener("pointerdown", finish, { once: true });
  window.addEventListener("keydown", finish, { once: true });
}

/**
 * Closes the span back over the page before an internal navigation, so the
 * next page's build continues the same gesture instead of starting a second,
 * unrelated one.
 *
 * Everything that is not a plain left-click on a same-origin document link is
 * left entirely alone: modified clicks (new tab, download, save), other-origin
 * links, `target`/`download` links, and in-page anchors all navigate exactly
 * as they did before this file existed.
 *
 * Nothing is torn down: the overlay is `display: none` between sequences and
 * the navigation itself ends the page.
 */
function initExitTransition(): void {
  document.addEventListener("click", (event) => {
    if (event.defaultPrevented || event.button !== 0) {
      return;
    }
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
      return;
    }

    const anchor = (event.target as Element | null)?.closest("a");
    if (!anchor?.href || anchor.target || anchor.hasAttribute("download")) {
      return;
    }

    const destination = new URL(anchor.href);
    if (destination.origin !== window.location.origin) {
      return;
    }
    // Same document, different fragment: an in-page jump, not a navigation.
    // Covering the screen for it would hide the very scroll it performs.
    if (
      destination.pathname === window.location.pathname &&
      destination.search === window.location.search
    ) {
      return;
    }

    event.preventDefault();
    root.dataset.pageLoad = "closing";
    debugLog("page-loader", "closing for", destination.pathname);
    window.setTimeout(() => {
      window.location.href = anchor.href;
    }, CLOSE_MS);
  });
}

/**
 * Clears the overlay when a page is restored from the back/forward cache.
 *
 * Without this, going back to a page that was left mid-exit restores it with
 * the panels closed over the content and no running sequence to open them —
 * bfcache restores the DOM and the attribute exactly as they were, but not the
 * pending `setTimeout` that would have navigated away.
 */
function initBfcacheReset(): void {
  window.addEventListener("pageshow", (event) => {
    if (event.persisted) {
      root.removeAttribute("data-page-load");
      debugLog("page-loader", "restored from bfcache, overlay cleared");
    }
  });
}
