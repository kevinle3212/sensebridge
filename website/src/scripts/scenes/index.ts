// Loader entry for Batch B's "First Light" 3D scenes (hero.ts, ambient.ts).
// Statically imports only the dependency-free quality gate (quality-gate.ts)
// — core.ts, and therefore `three`, is dynamic-imported below so it lands in
// its own lazy chunk, fetched only once a [data-scene] container is about to
// enter view. Self-running, same side-effect-import pattern as ../motion.
import type { MountedScene, SceneFactory } from "./core";
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

if (webglAllowed()) {
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
          },
        );
      }
    },
    { rootMargin: "200px" },
  );

  document.querySelectorAll<HTMLElement>("[data-scene]").forEach((container) => {
    observer.observe(container);
  });

  window.addEventListener("pagehide", () => {
    mountedScenes.forEach((scene) => {
      scene.dispose();
    });
  });
}
