// Ambient scene: a sparse, near-static page-wide point field (BaseLayout.astro
// → [data-scene="ambient"]) sitting behind every page's content. No bloom, no
// parallax, no camera motion — the field's own built-in drift (core.ts's
// createPointField) is the only movement.
import {
  approachColor,
  approachScalar,
  createPointField,
  type SceneContext,
  type SceneInstance,
} from "./core";

const CAMERA_Z = 8;
// Dark ceiling; light theme lands under its own ~0.18 ceiling for free since
// palette.particleOpacityScale is 0.5 there (see core.ts's PALETTES).
const MAX_OPACITY = 0.35;

export default function createAmbientScene(ctx: SceneContext): SceneInstance {
  const { renderer, scene, camera, theme } = ctx;

  camera.position.set(0, 0, CAMERA_Z);

  const pointField = createPointField({
    count: 600,
    spread: 10,
    baseSize: 0.05,
    sizeVariation: 0.5,
    additive: false,
  });
  scene.add(pointField.points);

  const currentColor = theme.palette.particleColor.clone();
  let currentOpacity = Math.min(MAX_OPACITY * theme.palette.particleOpacityScale, MAX_OPACITY);

  return {
    render(_elapsedSeconds: number, deltaSeconds: number): void {
      const palette = theme.palette;

      approachColor(currentColor, palette.particleColor, deltaSeconds);
      pointField.setColor(currentColor);

      currentOpacity = approachScalar(
        currentOpacity,
        Math.min(MAX_OPACITY * palette.particleOpacityScale, MAX_OPACITY),
        deltaSeconds,
      );
      pointField.setOpacity(currentOpacity);
      pointField.update(deltaSeconds);

      renderer.render(scene, camera);
    },

    dispose(): void {
      pointField.dispose();
    },
  };
}
