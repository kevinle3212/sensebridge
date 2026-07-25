// @ts-check
// No-flash theme bootstrap: runs before body paint so the page never
// renders one theme and then flips. Mirrors the toggle's own resolution
// logic in Header.astro — kept here too since this must run standalone,
// synchronously, before that component's script loads.
//
// External (not inline) so the site's CSP can be script-src 'self' with no
// 'unsafe-inline' or per-script hash — see vercel.json.
(() => {
  const STORAGE_KEY = "sb-theme";
  const media = window.matchMedia("(prefers-color-scheme: dark)");

  /**
   * A true first visit (nothing ever stored) defaults to "dark" — DESIGN.md's
   * "dark (default), light, and system" — not the OS preference. An explicit
   * "system" choice is stored as the literal string "system" (see Header.astro's
   * applyMode) and still resolves via the OS preference below.
   * @param {string | null} stored
   * @returns {"light" | "dark"}
   */
  function resolve(stored) {
    if (stored === "light" || stored === "dark") {
      return stored;
    }
    if (stored === "system") {
      return media.matches ? "dark" : "light";
    }
    return "dark";
  }

  function apply() {
    /** @type {string | null} */
    let stored;
    try {
      stored = localStorage.getItem(STORAGE_KEY);
    } catch {
      stored = null;
    }
    const resolved = resolve(stored);
    document.documentElement.dataset.theme = resolved;
    debug("stored:", stored, "→ applied:", resolved);
  }

  /**
   * Mirrors src/scripts/debug.ts's opt-in console logging.
   *
   * Duplicated rather than imported for the same reason resolve() is: this file
   * must run standalone and synchronously before any bundled module exists, so
   * it cannot import from src/. "Why did it load light instead of dark?" is
   * decided here, before anything that could log it has been fetched.
   * @param {...unknown} args
   */
  function debug(...args) {
    try {
      if (localStorage.getItem("sb-debug") !== "1") {
        return;
      }
    } catch {
      return;
    }
    // eslint-disable-next-line no-console
    console.debug("[sb:theme]", ...args);
  }

  apply();
  // Only live-update on an OS-level scheme change when the visitor hasn't
  // picked an explicit light/dark mode (i.e. mode is "system" or unset) — an
  // explicit choice must never be overridden by the OS.
  media.addEventListener("change", apply);
})();
