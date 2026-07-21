// Spatial Future scene: a wireframe pair of glasses that turns slowly in
// place, with a small signal point periodically tracing the frame — the
// same "sense, reason, render" pipeline metaphor as hero.ts/phone.ts,
// rendered on hardware that SpatialFuture.astro's copy is careful to frame
// as a possibility, not a product. Mounted by scenes/index.ts via core.ts's
// mountScene() once quality-gate.ts's webglAllowed() and the stage's
// [data-scene="glasses"] container both agree it should run.
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import type { Vector3 } from "three";
import {
  approachColor,
  approachScalar,
  createPointerParallax,
  type SceneContext,
  type SceneInstance,
} from "./core";

const CAMERA_BASE_Z = 3.2;

// Frame proportions, unscaled — then the whole group is scaled down by
// GLASSES_SCALE (below) to comfortably fit the ~32deg-fov frustum at
// CAMERA_BASE_Z across the stage's narrowest expected aspect ratio (the
// desktop layout's near-square stage; see SpatialFuture.module.scss).
const LENS_RADIUS = 0.55;
const LENS_TUBE = 0.012;
const LENS_OFFSET_X = 0.62;
const HINGE_X = LENS_OFFSET_X + LENS_RADIUS;
const TEMPLE_TIP_X = HINGE_X + 0.45;
const TEMPLE_TIP_Y = 0.05;
const TEMPLE_TIP_Z = 0.6;
const HINGE_RADIUS = 0.04;
const BROWLINE_WIDTH = HINGE_X * 2;
const BROWLINE_Y = LENS_RADIUS + 0.15;
const GLASSES_SCALE = 0.42;

const ROTATION_SPEED_Y = 0.15; // rad/s, "stately"
const SWAY_AMPLITUDE_X = 0.05; // rad
const SWAY_PERIOD_SECONDS = 8;

const LINE_BASE_OPACITY = 0.55;
const LENS_BASE_OPACITY = 0.7;

const SHIMMER_COUNT = 150;
const SHIMMER_JITTER = 0.05;
const SHIMMER_BASE_OPACITY = 0.4;
const SHIMMER_BREATHE_PERIOD_SECONDS = 5;

// Signal traveler: every SIGNAL_INTERVAL_SECONDS it spends SIGNAL_TRAVEL_SECONDS
// tracing the frame, then SIGNAL_PULSE_SECONDS fading a soft warm pulse at
// the right temple tip, then rests until the next cycle.
const SIGNAL_INTERVAL_SECONDS = 5;
const SIGNAL_TRAVEL_SECONDS = 2.5;
const SIGNAL_PULSE_SECONDS = 0.6;
const SIGNAL_WARM_START = 0.75; // fraction of travel where the color starts warming
const SIGNAL_RADIUS = 0.03;
const SIGNAL_PULSE_GROWTH = 2.5;

function smoothstep(edgeLow: number, edgeHigh: number, value: number): number {
  const t = Math.min(1, Math.max(0, (value - edgeLow) / (edgeHigh - edgeLow)));
  return t * t * (3 - 2 * t);
}

export default function createGlassesScene(ctx: SceneContext): SceneInstance {
  const { three: THREE, renderer, scene, camera, container, theme } = ctx;

  camera.position.set(0, 0, CAMERA_BASE_Z);
  const cameraBase = camera.position.clone();

  const glassesGroup = new THREE.Group();
  glassesGroup.scale.setScalar(GLASSES_SCALE);
  scene.add(glassesGroup);

  // --- Lens rings (a torus pair, not lines — reads cleaner rotating in 3D
  // than a flat circle) ------------------------------------------------------
  const lensMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const lensGeometry = new THREE.TorusGeometry(LENS_RADIUS, LENS_TUBE, 8, 48);
  const leftLens = new THREE.Mesh(lensGeometry, lensMaterial);
  leftLens.position.x = -LENS_OFFSET_X;
  const rightLens = new THREE.Mesh(lensGeometry, lensMaterial);
  rightLens.position.x = LENS_OFFSET_X;
  glassesGroup.add(leftLens, rightLens);

  // --- Structural line-art: temples + browline (shared material — both are
  // resting frame, not the signal) -------------------------------------------
  const structureMaterial = new THREE.LineBasicMaterial({
    transparent: true,
    opacity: LINE_BASE_OPACITY,
  });

  const templePositions = new Float32Array([
    -HINGE_X,
    0,
    0,
    -TEMPLE_TIP_X,
    TEMPLE_TIP_Y,
    TEMPLE_TIP_Z,
    HINGE_X,
    0,
    0,
    TEMPLE_TIP_X,
    TEMPLE_TIP_Y,
    TEMPLE_TIP_Z,
  ]);
  const templeGeometry = new THREE.BufferGeometry();
  templeGeometry.setAttribute("position", new THREE.BufferAttribute(templePositions, 3));
  glassesGroup.add(new THREE.LineSegments(templeGeometry, structureMaterial));

  const browlineBoxGeometry = new THREE.BoxGeometry(BROWLINE_WIDTH, 0.05, 0.03);
  const browlineGeometry = new THREE.EdgesGeometry(browlineBoxGeometry);
  const browline = new THREE.LineSegments(browlineGeometry, structureMaterial);
  browline.position.y = BROWLINE_Y;
  glassesGroup.add(browline);

  // --- Bridge: a small curve connecting the two lenses' inner edges,
  // reused below as the middle leg of the signal traveler's path ------------
  const bridgeCurve = new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(-LENS_OFFSET_X + LENS_RADIUS, 0, 0),
    new THREE.Vector3(0, -0.05, 0.15),
    new THREE.Vector3(LENS_OFFSET_X - LENS_RADIUS, 0, 0),
  );
  const bridgeGeometry = new THREE.BufferGeometry().setFromPoints(bridgeCurve.getPoints(16));
  glassesGroup.add(new THREE.Line(bridgeGeometry, structureMaterial));

  // --- Hinge accents: a tiny warm sphere where each temple meets its lens --
  const hingeMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const hingeGeometry = new THREE.SphereGeometry(HINGE_RADIUS, 12, 12);
  const leftHinge = new THREE.Mesh(hingeGeometry, hingeMaterial);
  leftHinge.position.x = -HINGE_X;
  const rightHinge = new THREE.Mesh(hingeGeometry, hingeMaterial);
  rightHinge.position.x = HINGE_X;
  glassesGroup.add(leftHinge, rightHinge);

  // --- Signal traveler path: left temple tip -> left hinge -> under the
  // left lens -> across the bridge -> under the right lens -> right hinge ->
  // right temple tip. Sampled every frame via .getPointAt(t, scratch) below —
  // never allocates a new Vector3 once the path is built. -------------------
  const signalPath = new THREE.CurvePath<Vector3>();
  signalPath.add(
    new THREE.LineCurve3(
      new THREE.Vector3(-TEMPLE_TIP_X, TEMPLE_TIP_Y, TEMPLE_TIP_Z),
      new THREE.Vector3(-HINGE_X, 0, 0),
    ),
  );
  signalPath.add(
    new THREE.QuadraticBezierCurve3(
      new THREE.Vector3(-HINGE_X, 0, 0),
      new THREE.Vector3(-LENS_OFFSET_X, -LENS_RADIUS - 0.1, 0.05),
      new THREE.Vector3(-LENS_OFFSET_X + LENS_RADIUS, 0, 0),
    ),
  );
  signalPath.add(bridgeCurve);
  signalPath.add(
    new THREE.QuadraticBezierCurve3(
      new THREE.Vector3(LENS_OFFSET_X - LENS_RADIUS, 0, 0),
      new THREE.Vector3(LENS_OFFSET_X, -LENS_RADIUS - 0.1, 0.05),
      new THREE.Vector3(HINGE_X, 0, 0),
    ),
  );
  signalPath.add(
    new THREE.LineCurve3(
      new THREE.Vector3(HINGE_X, 0, 0),
      new THREE.Vector3(TEMPLE_TIP_X, TEMPLE_TIP_Y, TEMPLE_TIP_Z),
    ),
  );

  const travelerMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const travelerGeometry = new THREE.SphereGeometry(SIGNAL_RADIUS, 12, 12);
  const traveler = new THREE.Mesh(travelerGeometry, travelerMaterial);
  glassesGroup.add(traveler);
  const travelerScratch = new THREE.Vector3();
  const travelerColorScratch = new THREE.Color();
  const rightTempleTip = new THREE.Vector3(TEMPLE_TIP_X, TEMPLE_TIP_Y, TEMPLE_TIP_Z);

  // --- Shimmer: a loose, static point cloud sampled along the same frame
  // path, breathing opacity rather than a driven per-point shader (simpler,
  // and this cloud never needs per-point size variation) --------------------
  const shimmerPositions = new Float32Array(SHIMMER_COUNT * 3);
  for (let i = 0; i < SHIMMER_COUNT; i += 1) {
    signalPath.getPointAt(Math.random(), travelerScratch);
    shimmerPositions[i * 3] = travelerScratch.x + (Math.random() - 0.5) * SHIMMER_JITTER;
    shimmerPositions[i * 3 + 1] = travelerScratch.y + (Math.random() - 0.5) * SHIMMER_JITTER;
    shimmerPositions[i * 3 + 2] = travelerScratch.z + (Math.random() - 0.5) * SHIMMER_JITTER;
  }
  const shimmerGeometry = new THREE.BufferGeometry();
  shimmerGeometry.setAttribute("position", new THREE.BufferAttribute(shimmerPositions, 3));
  const shimmerMaterial = new THREE.PointsMaterial({
    size: 0.02,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  glassesGroup.add(new THREE.Points(shimmerGeometry, shimmerMaterial));

  const parallax = createPointerParallax(container, camera, cameraBase, [glassesGroup]);

  const composer = new EffectComposer(renderer);
  const renderPass = new RenderPass(scene, camera);
  const bloomPass = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.8, 0.4, 0.85);
  composer.addPass(renderPass);
  composer.addPass(bloomPass);

  // Theme-lerped colors/opacities, reused every frame (never reallocated) —
  // see core.ts's approachColor/approachScalar.
  const currentLineColor = theme.palette.particleColor.clone();
  const currentWarmColor = theme.palette.warmColor.clone();
  let currentLineOpacity = LINE_BASE_OPACITY * theme.palette.particleOpacityScale;
  let currentLensOpacity = LENS_BASE_OPACITY * theme.palette.particleOpacityScale;
  let currentHingeOpacity = theme.palette.emissiveIntensity;

  return {
    render(elapsedSeconds: number, deltaSeconds: number): void {
      const palette = theme.palette;

      approachColor(currentLineColor, palette.particleColor, deltaSeconds);
      structureMaterial.color.copy(currentLineColor);
      lensMaterial.color.copy(currentLineColor);
      shimmerMaterial.color.copy(currentLineColor);

      currentLineOpacity = approachScalar(
        currentLineOpacity,
        LINE_BASE_OPACITY * palette.particleOpacityScale,
        deltaSeconds,
      );
      structureMaterial.opacity = currentLineOpacity;

      currentLensOpacity = approachScalar(
        currentLensOpacity,
        LENS_BASE_OPACITY * palette.particleOpacityScale,
        deltaSeconds,
      );
      lensMaterial.opacity = currentLensOpacity;

      approachColor(currentWarmColor, palette.warmColor, deltaSeconds);
      hingeMaterial.color.copy(currentWarmColor);
      currentHingeOpacity = approachScalar(
        currentHingeOpacity,
        palette.emissiveIntensity,
        deltaSeconds,
      );
      hingeMaterial.opacity = currentHingeOpacity;

      const shimmerBreathe =
        0.6 +
        0.4 *
          (0.5 + 0.5 * Math.sin((elapsedSeconds / SHIMMER_BREATHE_PERIOD_SECONDS) * Math.PI * 2));
      shimmerMaterial.opacity =
        SHIMMER_BASE_OPACITY * palette.particleOpacityScale * shimmerBreathe;

      // Signal traveler: trace the frame, then a soft warm pulse at
      // the right temple tip, then rest until the next cycle.
      const cycleSeconds = elapsedSeconds % SIGNAL_INTERVAL_SECONDS;
      if (cycleSeconds < SIGNAL_TRAVEL_SECONDS) {
        const travelProgress = cycleSeconds / SIGNAL_TRAVEL_SECONDS;
        signalPath.getPointAt(travelProgress, travelerScratch);
        traveler.position.copy(travelerScratch);
        traveler.visible = true;
        traveler.scale.setScalar(1);
        const warmBlend = smoothstep(SIGNAL_WARM_START, 1, travelProgress);
        travelerColorScratch.copy(currentLineColor).lerp(currentWarmColor, warmBlend);
        travelerMaterial.color.copy(travelerColorScratch);
        travelerMaterial.opacity = 1;
      } else if (cycleSeconds < SIGNAL_TRAVEL_SECONDS + SIGNAL_PULSE_SECONDS) {
        const pulseProgress = (cycleSeconds - SIGNAL_TRAVEL_SECONDS) / SIGNAL_PULSE_SECONDS;
        traveler.position.copy(rightTempleTip);
        traveler.visible = true;
        traveler.scale.setScalar(1 + pulseProgress * SIGNAL_PULSE_GROWTH);
        travelerMaterial.color.copy(currentWarmColor);
        travelerMaterial.opacity = 1 - pulseProgress;
      } else {
        traveler.visible = false;
      }

      // Slow continuous turn plus pointer-tilt parallax: parallax.update()
      // owns rotation.x/z on glassesGroup (see core.ts's createPointerParallax)
      // and sets it every frame, so the idle sway below is added on top of
      // that fresh tilt value rather than fighting it.
      glassesGroup.rotation.y += ROTATION_SPEED_Y * deltaSeconds;
      parallax.update();
      glassesGroup.rotation.x +=
        Math.sin((elapsedSeconds / SWAY_PERIOD_SECONDS) * Math.PI * 2) * SWAY_AMPLITUDE_X;

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
      lensGeometry.dispose();
      lensMaterial.dispose();
      templeGeometry.dispose();
      browlineBoxGeometry.dispose();
      browlineGeometry.dispose();
      structureMaterial.dispose();
      bridgeGeometry.dispose();
      hingeGeometry.dispose();
      hingeMaterial.dispose();
      travelerGeometry.dispose();
      travelerMaterial.dispose();
      shimmerGeometry.dispose();
      shimmerMaterial.dispose();
      renderPass.dispose();
      bloomPass.dispose();
      parallax.dispose();
    },
  };
}
