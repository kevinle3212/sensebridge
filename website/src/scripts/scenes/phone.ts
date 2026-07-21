// Phone Exploded scene: an abstract wireframe iPhone in three component
// groups (rear/sensing, middle/reasoning, front/rendering) that pulls apart
// as PhoneExploded.astro's [data-explode-track] scrolls past. Mounted by
// scenes/index.ts via core.ts's mountScene() once quality-gate.ts's
// webglAllowed() and the stage's [data-scene="phone"] container both agree
// it should run.
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import {
  approachColor,
  approachScalar,
  createPointerParallax,
  type SceneContext,
  type SceneInstance,
} from "./core";

const CAMERA_BASE_Z = 5.5;

// Shared phone-body proportions — every plate is the same footprint,
// offset only in depth (z), so the three layers read as one exploding
// device rather than three unrelated shapes.
const PLATE_WIDTH = 1.5;
const PLATE_HEIGHT = 3.1;
const REAR_PLATE_DEPTH = 0.06;
const BOARD_DEPTH = 0.04;
const FRONT_PLATE_DEPTH = 0.05;

const LENS_RADIUS = 0.12;
const LENS_DEPTH = 0.02;
const LENS_OFFSET_X = 0.25;
const LENS_OFFSET_Y = 1.1;
const LIDAR_RADIUS = 0.04;

const CHIP_SIZE = 0.4;
const CHIP_DEPTH = 0.08;
const CHIP_CORE_SIZE = 0.18;
const CHIP_CORE_DEPTH = 0.09;
const CHIP_ACTIVITY_COUNT = 200;
const CHIP_ACTIVITY_RADIUS_MIN = 0.15;
const CHIP_ACTIVITY_RADIUS_MAX = 0.4;

const SPEAKER_WIDTH = 0.5;
const SPEAKER_HEIGHT = 0.06;
const SPEAKER_DEPTH = 0.03;
const SPEAKER_OFFSET_Y = 1.0;
const HAPTIC_GRID_COLUMNS = 8;
const HAPTIC_GRID_ROWS = 5;
const HAPTIC_GRID_COUNT = HAPTIC_GRID_COLUMNS * HAPTIC_GRID_ROWS;
const HAPTIC_DOT_SPACING = 0.12;
const HAPTIC_GRID_BASE_Y = -1.1;

const POINT_BASE_SIZE = 0.035;

// Explosion mapping: assembled (progress 0) vs. fully separated
// (progress 1). The middle/reasoning group never moves — only the outer
// two groups slide apart in z, with a slight y fan.
const GROUP_A_ASSEMBLED_Z = -0.15;
const GROUP_A_EXPLODED_Z = -1.4;
const GROUP_A_EXPLODED_Y = -0.25;
const GROUP_C_ASSEMBLED_Z = 0.15;
const GROUP_C_EXPLODED_Z = 1.4;
const GROUP_C_EXPLODED_Y = 0.25;

// Idle turntable sway, so the stacked layers read as having depth even at
// rest — a fixed ~20° base angle plus a slow ~0.1 rad total sway.
const IDLE_BASE_ANGLE_DEGREES = 20;
const IDLE_SWAY_RADIANS = 0.1;
const IDLE_SWAY_PERIOD_SECONDS = 6;

// Group emphasis: each third of scroll progress "activates" one group's
// line/point opacity, the other two rest.
const ACTIVE_OPACITY = 0.9;
const RESTING_OPACITY = 0.35;
const PROGRESS_THIRD = 1 / 3;
const PROGRESS_TWO_THIRDS = 2 / 3;

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

export default function createPhoneScene(ctx: SceneContext): SceneInstance {
  const { three: THREE, renderer, scene, camera, container, theme } = ctx;

  camera.position.set(0, 0, CAMERA_BASE_Z);
  const cameraBase = camera.position.clone();

  const phoneGroup = new THREE.Group();
  scene.add(phoneGroup);

  // --- Group A: rear plate + camera + LiDAR (sensing) ---------------------
  const groupA = new THREE.Group();
  phoneGroup.add(groupA);

  const lineMaterialA = new THREE.LineBasicMaterial({ transparent: true });
  const rearPlateGeometry = new THREE.BoxGeometry(PLATE_WIDTH, PLATE_HEIGHT, REAR_PLATE_DEPTH);
  const rearPlateEdges = new THREE.EdgesGeometry(rearPlateGeometry);
  groupA.add(new THREE.LineSegments(rearPlateEdges, lineMaterialA));

  const lensGeometry = new THREE.CylinderGeometry(LENS_RADIUS, LENS_RADIUS, LENS_DEPTH, 16);
  const lensEdges = new THREE.EdgesGeometry(lensGeometry);
  const lens1 = new THREE.LineSegments(lensEdges, lineMaterialA);
  lens1.rotation.x = Math.PI / 2;
  lens1.position.set(-LENS_OFFSET_X, LENS_OFFSET_Y, REAR_PLATE_DEPTH);
  const lens2 = lens1.clone();
  lens2.position.set(LENS_OFFSET_X, LENS_OFFSET_Y, REAR_PLATE_DEPTH);
  groupA.add(lens1, lens2);

  const lidarGeometry = new THREE.SphereGeometry(LIDAR_RADIUS, 12, 12);
  const lidarMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const lidarDot = new THREE.Mesh(lidarGeometry, lidarMaterial);
  lidarDot.position.set(0, LENS_OFFSET_Y - 0.3, REAR_PLATE_DEPTH);
  groupA.add(lidarDot);

  // --- Group B: board + chip + neural activity (reasoning) ----------------
  const groupB = new THREE.Group();
  phoneGroup.add(groupB);

  const lineMaterialB = new THREE.LineBasicMaterial({ transparent: true });
  const boardGeometry = new THREE.BoxGeometry(PLATE_WIDTH, PLATE_HEIGHT, BOARD_DEPTH);
  const boardEdges = new THREE.EdgesGeometry(boardGeometry);
  groupB.add(new THREE.LineSegments(boardEdges, lineMaterialB));

  const chipGeometry = new THREE.BoxGeometry(CHIP_SIZE, CHIP_SIZE, CHIP_DEPTH);
  const chipEdges = new THREE.EdgesGeometry(chipGeometry);
  groupB.add(new THREE.LineSegments(chipEdges, lineMaterialB));

  const chipCoreGeometry = new THREE.BoxGeometry(CHIP_CORE_SIZE, CHIP_CORE_SIZE, CHIP_CORE_DEPTH);
  const chipCoreMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  groupB.add(new THREE.Mesh(chipCoreGeometry, chipCoreMaterial));

  // Neural activity: a jittered point cloud hugging the chip, flattened in
  // z so it reads as activity on the board rather than a loose sphere.
  const chipActivityPositions = new Float32Array(CHIP_ACTIVITY_COUNT * 3);
  for (let i = 0; i < CHIP_ACTIVITY_COUNT; i += 1) {
    const radius =
      CHIP_ACTIVITY_RADIUS_MIN +
      Math.random() * (CHIP_ACTIVITY_RADIUS_MAX - CHIP_ACTIVITY_RADIUS_MIN);
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(Math.random() * 2 - 1);
    chipActivityPositions[i * 3] = radius * Math.sin(phi) * Math.cos(theta);
    chipActivityPositions[i * 3 + 1] = radius * Math.sin(phi) * Math.sin(theta);
    chipActivityPositions[i * 3 + 2] = radius * Math.cos(phi) * 0.3;
  }
  const chipActivityGeometry = new THREE.BufferGeometry();
  chipActivityGeometry.setAttribute(
    "position",
    new THREE.BufferAttribute(chipActivityPositions, 3),
  );
  const chipActivityMaterial = new THREE.PointsMaterial({
    size: POINT_BASE_SIZE,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  groupB.add(new THREE.Points(chipActivityGeometry, chipActivityMaterial));

  // --- Group C: front face + speaker + haptic grid (rendering) ------------
  const groupC = new THREE.Group();
  phoneGroup.add(groupC);

  const lineMaterialC = new THREE.LineBasicMaterial({ transparent: true });
  const frontPlateGeometry = new THREE.BoxGeometry(PLATE_WIDTH, PLATE_HEIGHT, FRONT_PLATE_DEPTH);
  const frontPlateEdges = new THREE.EdgesGeometry(frontPlateGeometry);
  groupC.add(new THREE.LineSegments(frontPlateEdges, lineMaterialC));

  const speakerGeometry = new THREE.BoxGeometry(SPEAKER_WIDTH, SPEAKER_HEIGHT, SPEAKER_DEPTH);
  const speakerEdges = new THREE.EdgesGeometry(speakerGeometry);
  const speakerSlot = new THREE.LineSegments(speakerEdges, lineMaterialC);
  speakerSlot.position.set(0, SPEAKER_OFFSET_Y, FRONT_PLATE_DEPTH);
  groupC.add(speakerSlot);

  // Haptic dot grid: a fixed 8x5 grid near the bottom of the front face.
  const hapticPositions = new Float32Array(HAPTIC_GRID_COUNT * 3);
  for (let i = 0; i < HAPTIC_GRID_COUNT; i += 1) {
    const column = i % HAPTIC_GRID_COLUMNS;
    const row = Math.floor(i / HAPTIC_GRID_COLUMNS);
    hapticPositions[i * 3] = (column - (HAPTIC_GRID_COLUMNS - 1) / 2) * HAPTIC_DOT_SPACING;
    hapticPositions[i * 3 + 1] = HAPTIC_GRID_BASE_Y + row * HAPTIC_DOT_SPACING;
    hapticPositions[i * 3 + 2] = FRONT_PLATE_DEPTH;
  }
  const hapticGeometry = new THREE.BufferGeometry();
  hapticGeometry.setAttribute("position", new THREE.BufferAttribute(hapticPositions, 3));
  const hapticMaterial = new THREE.PointsMaterial({
    size: POINT_BASE_SIZE,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  groupC.add(new THREE.Points(hapticGeometry, hapticMaterial));

  const parallax = createPointerParallax(container, camera, cameraBase, [phoneGroup]);
  const idleBaseAngle = THREE.MathUtils.degToRad(IDLE_BASE_ANGLE_DEGREES);

  // The track this stage's explosion progress scrubs against — see
  // PhoneExploded.astro's [data-explode-track]. Looked up once; read via a
  // fresh getBoundingClientRect() every frame below (cheap, single element).
  const track = container.closest<HTMLElement>("[data-explode-track]");
  let smoothProgress = 0;

  const composer = new EffectComposer(renderer);
  const renderPass = new RenderPass(scene, camera);
  const bloomPass = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.8, 0.4, 0.85);
  composer.addPass(renderPass);
  composer.addPass(bloomPass);

  // Theme-lerped colors/opacities, reused every frame (never reallocated) —
  // see core.ts's approachColor/approachScalar. Shared across materials that
  // always chase the same target (all lines share one color, both point
  // clusters share another, both warm accents share a third).
  const currentLineColor = theme.palette.particleColor.clone();
  const currentPointColor = theme.palette.particleColor.clone();
  const currentAccentColor = theme.palette.warmColor.clone();
  let currentAccentOpacity = theme.palette.emissiveIntensity;
  let currentLineOpacityA = RESTING_OPACITY * theme.palette.particleOpacityScale;
  let currentLineOpacityB = RESTING_OPACITY * theme.palette.particleOpacityScale;
  let currentLineOpacityC = RESTING_OPACITY * theme.palette.particleOpacityScale;
  let currentChipPointsOpacity = currentLineOpacityB;
  let currentHapticPointsOpacity = currentLineOpacityC;

  return {
    render(elapsedSeconds: number, deltaSeconds: number): void {
      const palette = theme.palette;

      approachColor(currentLineColor, palette.particleColor, deltaSeconds);
      lineMaterialA.color.copy(currentLineColor);
      lineMaterialB.color.copy(currentLineColor);
      lineMaterialC.color.copy(currentLineColor);

      approachColor(currentPointColor, palette.particleColor, deltaSeconds);
      chipActivityMaterial.color.copy(currentPointColor);
      hapticMaterial.color.copy(currentPointColor);

      approachColor(currentAccentColor, palette.warmColor, deltaSeconds);
      lidarMaterial.color.copy(currentAccentColor);
      chipCoreMaterial.color.copy(currentAccentColor);
      currentAccentOpacity = approachScalar(
        currentAccentOpacity,
        palette.emissiveIntensity,
        deltaSeconds,
      );
      lidarMaterial.opacity = currentAccentOpacity;
      chipCoreMaterial.opacity = currentAccentOpacity;

      // Explosion scrub: how far the track has scrolled through the
      // viewport, 0 (top just reached) to 1 (bottom about to leave).
      const trackRect = track?.getBoundingClientRect();
      const rawProgress = trackRect
        ? clamp01(-trackRect.top / Math.max(trackRect.height - window.innerHeight, 1))
        : 0;
      smoothProgress = approachScalar(smoothProgress, rawProgress, deltaSeconds);

      groupA.position.z = THREE.MathUtils.lerp(
        GROUP_A_ASSEMBLED_Z,
        GROUP_A_EXPLODED_Z,
        smoothProgress,
      );
      groupA.position.y = THREE.MathUtils.lerp(0, GROUP_A_EXPLODED_Y, smoothProgress);
      groupC.position.z = THREE.MathUtils.lerp(
        GROUP_C_ASSEMBLED_Z,
        GROUP_C_EXPLODED_Z,
        smoothProgress,
      );
      groupC.position.y = THREE.MathUtils.lerp(0, GROUP_C_EXPLODED_Y, smoothProgress);

      // Group emphasis: one third of progress each, smoothed rather than
      // snapped so crossing a boundary eases in.
      const targetOpacityA =
        (smoothProgress < PROGRESS_THIRD ? ACTIVE_OPACITY : RESTING_OPACITY) *
        palette.particleOpacityScale;
      const targetOpacityB =
        (smoothProgress >= PROGRESS_THIRD && smoothProgress < PROGRESS_TWO_THIRDS
          ? ACTIVE_OPACITY
          : RESTING_OPACITY) * palette.particleOpacityScale;
      const targetOpacityC =
        (smoothProgress >= PROGRESS_TWO_THIRDS ? ACTIVE_OPACITY : RESTING_OPACITY) *
        palette.particleOpacityScale;

      currentLineOpacityA = approachScalar(currentLineOpacityA, targetOpacityA, deltaSeconds);
      currentLineOpacityB = approachScalar(currentLineOpacityB, targetOpacityB, deltaSeconds);
      currentLineOpacityC = approachScalar(currentLineOpacityC, targetOpacityC, deltaSeconds);
      lineMaterialA.opacity = currentLineOpacityA;
      lineMaterialB.opacity = currentLineOpacityB;
      lineMaterialC.opacity = currentLineOpacityC;

      currentChipPointsOpacity = approachScalar(
        currentChipPointsOpacity,
        targetOpacityB,
        deltaSeconds,
      );
      chipActivityMaterial.opacity = currentChipPointsOpacity;
      currentHapticPointsOpacity = approachScalar(
        currentHapticPointsOpacity,
        targetOpacityC,
        deltaSeconds,
      );
      hapticMaterial.opacity = currentHapticPointsOpacity;

      // Idle turntable sway on top of the ~20° resting angle, so the
      // stacked layers read as having depth even before any scroll.
      const idleSway =
        Math.sin((elapsedSeconds / IDLE_SWAY_PERIOD_SECONDS) * Math.PI * 2) *
        (IDLE_SWAY_RADIANS / 2);
      phoneGroup.rotation.y = idleBaseAngle + idleSway;

      parallax.update();

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
      rearPlateGeometry.dispose();
      rearPlateEdges.dispose();
      lensGeometry.dispose();
      lensEdges.dispose();
      lidarGeometry.dispose();
      lineMaterialA.dispose();
      lidarMaterial.dispose();

      boardGeometry.dispose();
      boardEdges.dispose();
      chipGeometry.dispose();
      chipEdges.dispose();
      chipCoreGeometry.dispose();
      chipActivityGeometry.dispose();
      lineMaterialB.dispose();
      chipCoreMaterial.dispose();
      chipActivityMaterial.dispose();

      frontPlateGeometry.dispose();
      frontPlateEdges.dispose();
      speakerGeometry.dispose();
      speakerEdges.dispose();
      hapticGeometry.dispose();
      lineMaterialC.dispose();
      hapticMaterial.dispose();

      renderPass.dispose();
      bloomPass.dispose();
      parallax.dispose();
    },
  };
}
