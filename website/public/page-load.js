// @ts-check
// Bootstrap for the "Span the gap" page-load sequence — see
// src/components/PageLoader.astro (the overlay) and src/scripts/page-loader.ts
// (the driver that takes over from here).
//
// This file exists, separate from the driver, for two reasons:
//
//   It must run before the first paint. The overlay's whole job is to cover
//   the page while it loads; a deferred module runs after the document has
//   already painted, so mounting the overlay from there would show the
//   finished page and *then* drop a loading screen over it. Same constraint,
//   same solution as theme-init.js.
//
//   It must be an external file, not an inline <script>. vercel.json's CSP is
//   `script-src 'self'` with no 'unsafe-inline' and no per-script hash, so a
//   browser refuses to execute inline script outright.
//
// It owns exactly two things: the decision to run the sequence at all, and the
// watchdog that guarantees the page is never left covered. Everything visual
// is CSS keyed off the `data-page-load` attribute this sets; everything
// stateful is the bundled driver.
(() => {
  const root = document.documentElement;

  // Hard opt-out, decided here rather than in CSS so the overlay never gets
  // even one frame: the sequence is decoration with a real time cost, and the
  // site's motion doctrine is that decoration does not run under `reduce`.
  // A reduced-motion visitor gets the page immediately, exactly as if this
  // feature did not exist.
  if (!window.matchMedia("(prefers-reduced-motion: no-preference)").matches) {
    return;
  }

  root.dataset.pageLoad = "building";

  // Fail-open watchdog. If the bundled driver never arrives — a chunk 404, a
  // parse error, a browser that chokes on something in it — nothing else would
  // ever clear this attribute and the visitor would stare at a covered page
  // forever. Removing the attribute is all it takes to reveal the page: the
  // overlay's own resting CSS state is `display: none`.
  //
  // Deliberately shorter than a patient visitor's tolerance and far longer
  // than the sequence itself (~2s worst case), so a healthy load never races
  // it. The driver clears the attribute itself on success, which makes this a
  // no-op.
  const WATCHDOG_MS = 4000;
  window.setTimeout(() => {
    if (root.dataset.pageLoad === "building") {
      delete root.dataset.pageLoad;
    }
  }, WATCHDOG_MS);
})();
