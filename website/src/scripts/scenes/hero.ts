// Hero scene ("First Light" ignition beat): a drifting depth field, a slow-
// rotating wireframe icosahedron, and a warm core that ignites once on load
// then settles into a subtle idle pulse. Mounted by scenes/index.ts via
// core.ts's mountScene() once quality-gate.ts's webglAllowed() and the hero's
// [data-scene="hero"] container both agree it should run.
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import {
  approachColor,
  approachScalar,
  createPointerParallax,
  createPointField,
  type SceneContext,
  type SceneInstance,
} from "./core";

const CAMERA_BASE_Z = 6;
const SCROLL_DOLLY_RANGE = 0.8;
const WIREFRAME_ROTATION_SPEED = 0.02;
const LINE_BASE_OPACITY = 0.35;
const CORE_RADIUS = 0.18;
const IGNITION_DURATION_SECONDS = 1.5;
const IGNITION_RING_GROWTH = 3;
const CORE_PULSE_PERIOD_SECONDS = 4;
const CORE_PULSE_SCALE_AMOUNT = 0.08;
const CORE_PULSE_OPACITY_AMOUNT = 0.15;

export default function createHeroScene(ctx: SceneContext): SceneInstance {
  const { three: THREE, renderer, scene, camera, container, theme } = ctx;

  camera.position.set(0, 0, CAMERA_BASE_Z);
  const cameraBase = camera.position.clone();
  const lookAtTarget = new THREE.Vector3(cameraBase.x, cameraBase.y, 0);
  let currentDollyZ = cameraBase.z;

  const pointField = createPointField({
    count: 4000,
    spread: 6,
    baseSize: 0.05,
    sizeVariation: 0.6,
    additive: true,
  });
  scene.add(pointField.points);

  const icosahedronGeometry = new THREE.IcosahedronGeometry(1.4, 2);
  const wireframeGeometry = new THREE.WireframeGeometry(icosahedronGeometry);
  const lineMaterial = new THREE.LineBasicMaterial({
    transparent: true,
    opacity: LINE_BASE_OPACITY,
  });
  const wireframe = new THREE.LineSegments(wireframeGeometry, lineMaterial);
  scene.add(wireframe);

  const coreGeometry = new THREE.SphereGeometry(CORE_RADIUS, 16, 16);
  const coreMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const core = new THREE.Mesh(coreGeometry, coreMaterial);
  scene.add(core);

  // One-shot "ignition beat": a ring expands from the core, signal-blue,
  // fading out over IGNITION_DURATION_SECONDS. Hidden (not disposed) once
  // spent, rather than removed from the scene, since it never needs to
  // replay.
  const ringGeometry = new THREE.RingGeometry(0.9, 1, 48);
  const ringMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const ignitionRing = new THREE.Mesh(ringGeometry, ringMaterial);
  scene.add(ignitionRing);

  const parallax = createPointerParallax(container, camera, cameraBase, [wireframe]);

  const composer = new EffectComposer(renderer);
  const renderPass = new RenderPass(scene, camera);
  const bloomPass = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.8, 0.4, 0.85);
  composer.addPass(renderPass);
  composer.addPass(bloomPass);

  // Theme-lerped colors/opacities, reused every frame (never reallocated) —
  // see core.ts's approachColor/approachScalar.
  const currentParticleColor = theme.palette.particleColor.clone();
  const currentLineColor = theme.palette.particleColor.clone();
  const currentCoreColor = theme.palette.warmColor.clone();
  let currentParticleOpacity = theme.palette.particleOpacityScale;
  let currentLineOpacity = LINE_BASE_OPACITY * theme.palette.particleOpacityScale;

  return {
    render(elapsedSeconds: number, deltaSeconds: number): void {
      const palette = theme.palette;

      approachColor(currentParticleColor, palette.particleColor, deltaSeconds);
      currentParticleOpacity = approachScalar(
        currentParticleOpacity,
        palette.particleOpacityScale,
        deltaSeconds,
      );
      pointField.setColor(currentParticleColor);
      pointField.setOpacity(currentParticleOpacity);
      pointField.update(deltaSeconds);

      approachColor(currentLineColor, palette.particleColor, deltaSeconds);
      currentLineOpacity = approachScalar(
        currentLineOpacity,
        LINE_BASE_OPACITY * palette.particleOpacityScale,
        deltaSeconds,
      );
      lineMaterial.color.copy(currentLineColor);
      lineMaterial.opacity = currentLineOpacity;
      wireframe.rotation.y += WIREFRAME_ROTATION_SPEED * deltaSeconds;

      approachColor(currentCoreColor, palette.warmColor, deltaSeconds);
      coreMaterial.color.copy(currentCoreColor);

      if (elapsedSeconds < IGNITION_DURATION_SECONDS) {
        const beatProgress = elapsedSeconds / IGNITION_DURATION_SECONDS;
        ringMaterial.color.copy(currentParticleColor);
        ringMaterial.opacity = 1 - beatProgress;
        ignitionRing.scale.setScalar(1 + beatProgress * IGNITION_RING_GROWTH);
      } else if (ignitionRing.visible) {
        ignitionRing.visible = false;
      }

      // Idle "breathing" pulse once the ignition beat has settled — a plain
      // sine on scale/opacity, no separate timer needed.
      const pulse =
        0.5 + 0.5 * Math.sin((elapsedSeconds / CORE_PULSE_PERIOD_SECONDS) * Math.PI * 2);
      core.scale.setScalar(1 + pulse * CORE_PULSE_SCALE_AMOUNT);
      coreMaterial.opacity = 1 - pulse * CORE_PULSE_OPACITY_AMOUNT;

      // Scroll dolly: camera eases toward `targetDollyZ` as the hero scrolls
      // past. parallax.update() always resets camera z to `cameraBase.z`
      // (see core.ts's createPointerParallax), so the dolly's z is applied
      // after and re-aimed at the origin.
      const scrollFraction = Math.min(window.scrollY / window.innerHeight, 1);
      const targetDollyZ = cameraBase.z + scrollFraction * SCROLL_DOLLY_RANGE;
      currentDollyZ = approachScalar(currentDollyZ, targetDollyZ, deltaSeconds);
      parallax.update();
      camera.position.z = currentDollyZ;
      camera.lookAt(lookAtTarget);

      if (palette.bloom) {
        composer.render();
      } else {
        renderer.render(scene, camera);
      }
    },

    resize(width: number, height: number): void {
      composer.setSize(width, height);
    },

    dispose(): void {
      pointField.dispose();
      icosahedronGeometry.dispose();
      wireframeGeometry.dispose();
      lineMaterial.dispose();
      coreGeometry.dispose();
      coreMaterial.dispose();
      ringGeometry.dispose();
      ringMaterial.dispose();
      renderPass.dispose();
      bloomPass.dispose();
      parallax.dispose();
    },
  };
}
