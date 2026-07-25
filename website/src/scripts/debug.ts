// Opt-in verbose logging for the site's client scripts, written to the browser
// console.
//
// Always on under `astro dev`. In a production build it stays off until the
// visitor opts in with `localStorage.setItem("sb-debug", "1")` and reloads —
// which is the point: the questions worth logging ("why is nothing animating?",
// "why is there no 3D?", "why did it load light instead of dark?") are usually
// asked about the deployed site, not the dev server, and a dev-only gate would
// be compiled out of the static build before it could answer any of them.
//
// The cost of keeping it in the production bundle is a handful of short strings
// and one `localStorage` read at load. Nothing is logged, and no work is done
// to build a log message, unless the flag is set.
const STORAGE_KEY = "sb-debug";

/**
 * Reads the opt-in flag, treating unavailable storage as "off".
 *
 * Private-browsing modes and blocked third-party storage make `localStorage`
 * throw on access rather than return null, and a debug helper must never be
 * the thing that breaks the page it is there to explain.
 */
function flagSet(): boolean {
  try {
    return localStorage.getItem(STORAGE_KEY) === "1";
  } catch {
    return false;
  }
}

// Resolved once at load rather than per call, so a logger sitting in a scroll
// or pointer path costs nothing after startup. Toggling the flag therefore
// needs a reload — standard for a debug switch, and cheaper than re-reading
// storage on every frame.
const enabled = import.meta.env.DEV || flagSet();

/**
 * Logs to the browser console under a `[sb:<scope>]` prefix when verbose
 * logging is on; a no-op otherwise.
 *
 * @param scope - Short subsystem tag, e.g. `"motion"` or `"scenes"`. Used as
 *   the console prefix so a single filter isolates one subsystem's output.
 * @param args - Values to log, passed through to the console unchanged.
 */
export function debugLog(scope: string, ...args: unknown[]): void {
  if (!enabled) {
    return;
  }
  // The one sanctioned console site in the site's client code — `no-console`
  // stays strict everywhere else so debug output can't leak in ad hoc.
  // eslint-disable-next-line no-console
  console.debug(`[sb:${scope}]`, ...args);
}
