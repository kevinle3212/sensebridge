// Batch B "First Light" 3D scenes: the quality gate every scene answers to.
// Deliberately dependency-free (no `three` import) so scenes/index.ts can
// call this *before* three.js is ever downloaded — a failing gate means the
// visitor's browser never fetches a single byte of the 3D bundle. See
// scenes/index.ts for how this is wired to the same reduced-motion-gated
// load timing as src/scripts/motion.ts.
export {};

// navigator.connection/deviceMemory are Chromium-only client-hint APIs with
// no lib.dom typings yet — narrowed locally rather than reaching for `any`.
interface NavigatorWithClientHints extends Navigator {
  connection?: { saveData?: boolean };
  deviceMemory?: number;
}

export function webglAllowed(): boolean {
  if (!window.matchMedia("(prefers-reduced-motion: no-preference)").matches) {
    return false;
  }

  const nav = navigator as NavigatorWithClientHints;
  if (nav.connection?.saveData === true) {
    return false;
  }
  if (nav.deviceMemory !== undefined && nav.deviceMemory < 4) {
    return false;
  }

  const probe = document.createElement("canvas");
  return probe.getContext("webgl2") !== null;
}
