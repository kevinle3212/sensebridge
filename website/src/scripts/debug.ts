// Opt-in verbose logging for the site's client scripts, written to the browser
// console.
//
// Always on under `astro dev`. In a production build it stays off until the
// visitor opts in and reloads, which is the point: the questions worth
// logging ("why is nothing animating?", "why is there no 3D?") are usually
// asked about the deployed site, not the dev server, and a dev-only gate
// would be compiled out of the static build before it could answer any of
// them. The flag lives in IndexedDB — key "sb-debug" in the "kv" store of the
// "sensebridge" database (see idb-store.ts) — set it via devtools' Application
// > IndexedDB panel, or `indexedDB.open("sensebridge").onsuccess = (e) =>
// e.target.result.transaction("kv", "readwrite").objectStore("kv").put("1",
// "sb-debug")` in the console.
//
// Note: `public/theme-init.js` (the no-flash theme bootstrap that must run
// synchronously, before this module or any bundle exists) keeps its own
// duplicated, `localStorage`-backed copy of this flag for "why did it load
// light instead of dark?" — see that file's own `debug()`. It is
// deliberately not wired to this one.
import { idbGet } from "./idb-store";

const STORAGE_KEY = "sb-debug";

// Resolved once at load rather than per call, so a logger sitting in a scroll
// or pointer path costs nothing after startup. Toggling the flag therefore
// needs a reload — standard for a debug switch, and cheaper than re-reading
// storage on every frame. IndexedDB has no synchronous read, so `enabled`
// starts as just the dev-mode check and flips true shortly after load if the
// visitor opted in on a prior visit; this module logs nothing that gates a
// visible result, so a debugLog() call in that brief window being dropped has
// no user-facing effect.
let enabled = import.meta.env.DEV;
if (!enabled) {
  void idbGet(STORAGE_KEY).then((stored) => {
    enabled = stored === "1";
  });
}

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
