// Loader entry for Batch B's "First Light" 3D scenes (hero.ts, ambient.ts).
// Statically imports only the dependency-free quality gate (quality-gate.ts)
// — core.ts, and therefore `three`, is dynamic-imported below so it lands in
// its own lazy chunk, fetched only once a [data-scene] container is about to
// enter view. Self-running, same side-effect-import pattern as ../motion.
import type { MountedScene, SceneFactory } from "./core";
import { debugLog } from "../debug";
import { webglAllowed } from "./quality-gate";

export {};

type SceneName = "hero" | "ambient" | "phone" | "glasses" | "bridge";

const sceneImporters: Record<SceneName, () => Promise<{ default: SceneFactory }>> = {
  hero: () => import("./hero"),
  ambient: () => import("./ambient"),
  phone: () => import("./phone"),
  glasses: () => import("./glasses"),
  bridge: () => import("./bridge"),
};

function isSceneName(value: string | undefined): value is SceneName {
  return (
    value === "hero" ||
    value === "ambient" ||
    value === "phone" ||
    value === "glasses" ||
    value === "bridge"
  );
}

// A missing 3D scene is either this gate saying no (weak GPU, reduced motion,
// no WebGL) or a chunk that never got fetched — the two logs below tell those
// apart without guessing.
const allowed = webglAllowed();
debugLog("scenes", "webgl quality gate:", allowed ? "allowed" : "blocked");

if (allowed) {
  const mountedScenes: MountedScene[] = [];

  const observer = new IntersectionObserver(
    (entries, obs) => {
      for (const entry of entries) {
        const container = entry.target;
        if (!entry.isIntersecting || !(container instanceof HTMLElement)) {
          continue;
        }
        obs.unobserve(container);
        const sceneName = container.dataset.scene;
        if (!isSceneName(sceneName)) {
          continue;
        }
        // `sceneName` is narrowed by isSceneName() to one of sceneImporters'
        // own keys, not arbitrary attacker input.
        // eslint-disable-next-line security/detect-object-injection
        void Promise.all([sceneImporters[sceneName](), import("./core")]).then(
          ([{ default: factory }, { mountScene }]) => {
            mountedScenes.push(mountScene(container, factory));
            debugLog("scenes", "mounted:", sceneName);
          },
        );
      }
    },
    { rootMargin: "200px" },
  );

  document.querySelectorAll<HTMLElement>("[data-scene]").forEach((container) => {
    observer.observe(container);
  });

  // Only a real unload frees the WebGL contexts. A bfcache freeze also fires
  // `pagehide` (with `persisted: true`), but there the document survives and
  // comes back untouched — and nothing re-runs this module, because
  // BaseLayout.astro imports it from a `load` listener and bfcache does not
  // re-fire `load`. Disposing on that path is a one-way door: the scene is
  // gone, `.scene-active` is off, and the visitor gets the static fallback art
  // for the rest of the session. Leaving the scenes mounted also skips
  // rebuilding renderers, geometry, and shaders on the way back, which is main
  // -thread work the restore does not need. If the browser drops the GL
  // context while the page is frozen, core.ts's `webglcontextlost` handler
  // still tears that scene down and restores its static art.
  window.addEventListener("pagehide", (event) => {
    if (event.persisted) {
      return;
    }
    mountedScenes.forEach((scene) => {
      scene.dispose();
    });
    mountedScenes.length = 0;
  });
}
