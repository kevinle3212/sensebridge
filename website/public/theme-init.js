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
   * @param {string | null} stored
   * @returns {"light" | "dark"}
   */
  function resolve(stored) {
    if (stored === "light" || stored === "dark") {
      return stored;
    }
    return media.matches ? "dark" : "light";
  }

  function apply() {
    /** @type {string | null} */
    let stored;
    try {
      stored = localStorage.getItem(STORAGE_KEY);
    } catch {
      stored = null;
    }
    document.documentElement.dataset.theme = resolve(stored);
  }

  apply();
  // Only live-update on an OS-level scheme change when the visitor hasn't
  // picked an explicit light/dark mode (i.e. mode is "system" or unset) — an
  // explicit choice must never be overridden by the OS.
  media.addEventListener("change", apply);
})();
