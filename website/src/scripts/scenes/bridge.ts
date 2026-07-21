// Signal Bridge scene: a wireframe suspension bridge that constructs itself
// (pylons rise, cables and hangers draw in, the deck closes from both ends)
// as SignalBridge.astro's section scrolls past, then a signal light crosses
// the finished deck left-to-right, warming on arrival — the product
// metaphor in DESIGN.md → "Signal Bridge" (SensingSource -> perception ->
// Reasoning -> RenderTarget), reframed as a scroll-scrubbed camera tracking
// shot. Mounted by scenes/index.ts via core.ts's mountScene() once
// quality-gate.ts's webglAllowed() and the section's [data-scene="bridge"]
// container both agree it should run.
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
import type {
  BufferGeometry,
  CurvePath,
  Group,
  LineBasicMaterial,
  Mesh,
  MeshBasicMaterial,
  Vector3,
} from "three";
import {
  approachColor,
  approachScalar,
  createPointerParallax,
  createPointField,
  type SceneContext,
  type SceneInstance,
} from "./core";

const CAMERA_BASE_Z = 5;
const CAMERA_BASE_Y = 0.6;
const CAMERA_X_START = -1.2;
const CAMERA_X_END = 1.2;

// Bridge proportions, in scene units — deck at y=0 local reference (see
// DECK_Y), pylons rising to PYLON_TOP_Y, deck spanning +-DECK_HALF_SPAN.
const PYLON_X = 2.2;
const DECK_Y = -0.4;
const PYLON_TOP_Y = 1;
const PYLON_HEIGHT = PYLON_TOP_Y - DECK_Y;
const PYLON_WIDTH = 0.12;
const PYLON_DEPTH = 0.12;
const CROSSBEAM_WIDTH = 0.5;
const CROSSBEAM_HEIGHT = 0.06;
const CROSSBEAM_DEPTH = 0.06;
const CROSSBEAM_HEIGHT_FRACTION = 0.55;

const DECK_HALF_SPAN = 3.2;
const DECK_THICKNESS = 0.05;

const CABLE_SAG_Y = 0.15;
const CABLE_SAMPLE_COUNT = 64;
const CABLE_POINT_COUNT = CABLE_SAMPLE_COUNT + 1;
const CENTERLINE_SAMPLE_COUNT = 32;
const CENTERLINE_POINT_COUNT = CENTERLINE_SAMPLE_COUNT + 1;

const HANGER_COUNT = 14;

const WATER_Y = DECK_Y - 1.3;
const WATER_SPREAD = 3.4;
const WATER_COUNT = 120;
const WATER_BASE_SIZE = 0.02;
const WATER_OPACITY = 0.12;

const STRUCTURE_OPACITY = 0.55;
const ACCENT_OPACITY = 0.85;

// Construction scrub sub-ranges (see DESIGN.md story: builds itself, then a
// signal crosses it) — all read against the same smoothed 0..1 progress.
const PYLON_RISE_START = 0;
const PYLON_RISE_END = 0.35;
const CABLE_DRAW_START = 0.25;
const CABLE_DRAW_END = 0.6;
const HANGER_REVEAL_START = 0.5;
const HANGER_REVEAL_END = 0.8;
const DECK_DRAW_START = 0.6;
const DECK_DRAW_END = 0.9;
const TRAVELER_GATE_PROGRESS = 0.92;

const SIGNAL_INTERVAL_SECONDS = 6;
const SIGNAL_TRAVEL_SECONDS = 2.2;
const SIGNAL_PULSE_SECONDS = 0.6;
const SIGNAL_WARM_START = 0.8;
const SIGNAL_RADIUS = 0.045;
const SIGNAL_PULSE_GROWTH = 2.5;
const SIGNAL_LIFT = 0.04;
const TRAIL_COUNT = 4;
const TRAIL_SPACING = 0.035;
const TRAIL_RADIUS_SCALE = 0.6;

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

function subProgress(start: number, end: number, value: number): number {
  return clamp01((value - start) / (end - start));
}

function smoothstep(edgeLow: number, edgeHigh: number, value: number): number {
  const t = subProgress(edgeLow, edgeHigh, value);
  return t * t * (3 - 2 * t);
}

interface Hanger {
  group: Group;
  geometry: BufferGeometry;
  material: LineBasicMaterial;
  revealThreshold: number;
  opacity: number;
}

interface TrailPoint {
  mesh: Mesh;
  material: MeshBasicMaterial;
  lag: number;
}

export default function createBridgeScene(ctx: SceneContext): SceneInstance {
  const { three: THREE, renderer, scene, camera, container, theme } = ctx;

  const cameraBase = new THREE.Vector3(CAMERA_X_START, CAMERA_BASE_Y, CAMERA_BASE_Z);
  camera.position.copy(cameraBase);
  camera.lookAt(cameraBase.x, cameraBase.y, 0);

  const bridgeGroup = new THREE.Group();
  scene.add(bridgeGroup);

  const structureMaterial = new THREE.LineBasicMaterial({ transparent: true });
  const accentMaterial = new THREE.LineBasicMaterial({ transparent: true });

  // --- Pylons: a tall thin box (edges) with a crossbeam, local origin at
  // the base so scale.y grows the tower upward from the deck. Both towers
  // share the same geometry/material, positioned by their group only. -----
  const pylonBoxGeometry = new THREE.BoxGeometry(PYLON_WIDTH, PYLON_HEIGHT, PYLON_DEPTH);
  pylonBoxGeometry.translate(0, PYLON_HEIGHT / 2, 0);
  const pylonEdges = new THREE.EdgesGeometry(pylonBoxGeometry);
  const crossbeamBoxGeometry = new THREE.BoxGeometry(
    CROSSBEAM_WIDTH,
    CROSSBEAM_HEIGHT,
    CROSSBEAM_DEPTH,
  );
  crossbeamBoxGeometry.translate(0, PYLON_HEIGHT * CROSSBEAM_HEIGHT_FRACTION, 0);
  const crossbeamEdges = new THREE.EdgesGeometry(crossbeamBoxGeometry);

  const pylonLeft = new THREE.Group();
  pylonLeft.position.set(-PYLON_X, DECK_Y, 0);
  pylonLeft.add(new THREE.LineSegments(pylonEdges, structureMaterial));
  pylonLeft.add(new THREE.LineSegments(crossbeamEdges, structureMaterial));
  const pylonRight = pylonLeft.clone();
  pylonRight.position.x = PYLON_X;
  bridgeGroup.add(pylonLeft, pylonRight);

  // --- Main cables: one CurvePath per side, deck end up over its pylon
  // top, sagging down toward the midspan low point. Sampled into a Line so
  // BufferGeometry.setDrawRange can scrub the "draws in" reveal. -----------
  function buildCablePath(sign: number): CurvePath<Vector3> {
    const outerX = sign * DECK_HALF_SPAN;
    const towerX = sign * PYLON_X;
    const path = new THREE.CurvePath<Vector3>();
    path.add(
      new THREE.LineCurve3(
        new THREE.Vector3(outerX, DECK_Y, 0),
        new THREE.Vector3(towerX, PYLON_TOP_Y, 0),
      ),
    );
    path.add(
      new THREE.QuadraticBezierCurve3(
        new THREE.Vector3(towerX, PYLON_TOP_Y, 0),
        new THREE.Vector3(towerX * 0.5, CABLE_SAG_Y - 0.15, 0),
        new THREE.Vector3(0, CABLE_SAG_Y, 0),
      ),
    );
    return path;
  }

  const cableGeometryLeft = new THREE.BufferGeometry().setFromPoints(
    buildCablePath(-1).getPoints(CABLE_SAMPLE_COUNT),
  );
  const cableGeometryRight = new THREE.BufferGeometry().setFromPoints(
    buildCablePath(1).getPoints(CABLE_SAMPLE_COUNT),
  );
  const cableLeft = new THREE.Line(cableGeometryLeft, accentMaterial);
  const cableRight = new THREE.Line(cableGeometryRight, accentMaterial);
  bridgeGroup.add(cableLeft, cableRight);

  // --- Hangers: vertical lines from the (approximate, parabolic) cable
  // height down to the deck, evenly spaced between the two towers. Each
  // gets its own material so the "appear sequentially" reveal can stagger
  // per hanger without a shared-opacity compromise. --------------------
  const hangers: Hanger[] = [];
  for (let index = 0; index < HANGER_COUNT; index += 1) {
    const spanFraction = (index + 1) / (HANGER_COUNT + 1);
    const x = THREE.MathUtils.lerp(-PYLON_X, PYLON_X, spanFraction);
    const cableHeightAtX = CABLE_SAG_Y + (PYLON_TOP_Y - CABLE_SAG_Y) * (Math.abs(x) / PYLON_X) ** 2;
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(0, 0, 0),
      new THREE.Vector3(0, cableHeightAtX - DECK_Y, 0),
    ]);
    const material = new THREE.LineBasicMaterial({ transparent: true });
    const group = new THREE.Group();
    group.position.set(x, DECK_Y, 0);
    group.add(new THREE.Line(geometry, material));
    bridgeGroup.add(group);
    hangers.push({
      group,
      geometry,
      material,
      revealThreshold: THREE.MathUtils.lerp(
        HANGER_REVEAL_START,
        HANGER_REVEAL_END,
        index / (HANGER_COUNT - 1),
      ),
      opacity: 0,
    });
  }

  // --- Deck: a thin box plank per half (structural), plus a brighter
  // center line per half (the signal path) — both halves anchored at their
  // outer tip so growing them draws the deck in from both ends toward the
  // center. -----------------------------------------------------------
  const deckHalfBoxLeft = new THREE.BoxGeometry(DECK_HALF_SPAN, DECK_THICKNESS, DECK_THICKNESS);
  deckHalfBoxLeft.translate(DECK_HALF_SPAN / 2, 0, 0);
  const deckHalfBoxRight = new THREE.BoxGeometry(DECK_HALF_SPAN, DECK_THICKNESS, DECK_THICKNESS);
  deckHalfBoxRight.translate(-DECK_HALF_SPAN / 2, 0, 0);
  const deckEdgesLeft = new THREE.EdgesGeometry(deckHalfBoxLeft);
  const deckEdgesRight = new THREE.EdgesGeometry(deckHalfBoxRight);

  const deckGroupLeft = new THREE.Group();
  deckGroupLeft.position.set(-DECK_HALF_SPAN, DECK_Y, 0);
  deckGroupLeft.add(new THREE.LineSegments(deckEdgesLeft, structureMaterial));
  const deckGroupRight = new THREE.Group();
  deckGroupRight.position.set(DECK_HALF_SPAN, DECK_Y, 0);
  deckGroupRight.add(new THREE.LineSegments(deckEdgesRight, structureMaterial));
  bridgeGroup.add(deckGroupLeft, deckGroupRight);

  function buildHalfLinePoints(fromX: number, toX: number): Vector3[] {
    const points: Vector3[] = [];
    for (let index = 0; index <= CENTERLINE_SAMPLE_COUNT; index += 1) {
      const t = index / CENTERLINE_SAMPLE_COUNT;
      points.push(new THREE.Vector3(THREE.MathUtils.lerp(fromX, toX, t), DECK_Y, 0));
    }
    return points;
  }

  const centerLineGeometryLeft = new THREE.BufferGeometry().setFromPoints(
    buildHalfLinePoints(-DECK_HALF_SPAN, 0),
  );
  const centerLineGeometryRight = new THREE.BufferGeometry().setFromPoints(
    buildHalfLinePoints(DECK_HALF_SPAN, 0),
  );
  const centerLineLeft = new THREE.Line(centerLineGeometryLeft, accentMaterial);
  const centerLineRight = new THREE.Line(centerLineGeometryRight, accentMaterial);
  bridgeGroup.add(centerLineLeft, centerLineRight);

  // --- Faint water/ground reference, always present at low opacity —
  // reuses core.ts's drifting point field rather than hand-rolling one. ----
  const waterField = createPointField({
    count: WATER_COUNT,
    spread: WATER_SPREAD,
    baseSize: WATER_BASE_SIZE,
    sizeVariation: 0.5,
    additive: true,
  });
  waterField.points.position.y = WATER_Y;
  bridgeGroup.add(waterField.points);

  // --- Signal traveler: a small sphere plus a short decaying trail, timed
  // independently of construction progress but only rendered once the
  // smoothed construction progress clears TRAVELER_GATE_PROGRESS. ---------
  const travelerMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const travelerGeometry = new THREE.SphereGeometry(SIGNAL_RADIUS, 12, 12);
  const traveler = new THREE.Mesh(travelerGeometry, travelerMaterial);
  bridgeGroup.add(traveler);

  const trailPoints: TrailPoint[] = [];
  for (let index = 0; index < TRAIL_COUNT; index += 1) {
    const material = new THREE.MeshBasicMaterial({ transparent: true });
    const mesh = new THREE.Mesh(travelerGeometry, material);
    mesh.scale.setScalar(TRAIL_RADIUS_SCALE);
    bridgeGroup.add(mesh);
    trailPoints.push({ mesh, material, lag: (index + 1) * TRAIL_SPACING });
  }

  const travelerScratch = new THREE.Vector3();
  const travelerColorScratch = new THREE.Color();
  const rightPylonPoint = new THREE.Vector3(PYLON_X, DECK_Y + SIGNAL_LIFT, 0);

  function travelerPositionAt(t: number, target: Vector3): void {
    target.set(THREE.MathUtils.lerp(-PYLON_X, PYLON_X, clamp01(t)), DECK_Y + SIGNAL_LIFT, 0);
  }

  const parallax = createPointerParallax(container, camera, cameraBase, []);

  const composer = new EffectComposer(renderer);
  const renderPass = new RenderPass(scene, camera);
  const bloomPass = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.8, 0.4, 0.85);
  composer.addPass(renderPass);
  composer.addPass(bloomPass);

  // The section this scene's construction progress scrubs against — see
  // SignalBridge.astro's [data-scene="bridge"] container, a child of the
  // #bridge section. Looked up once; read via a fresh getBoundingClientRect()
  // every frame below (cheap, single element).
  const track = container.closest<HTMLElement>("section");
  let smoothProgress = 0;

  // Theme-lerped colors/opacities, reused every frame (never reallocated) —
  // see core.ts's approachColor/approachScalar.
  const currentLineColor = theme.palette.particleColor.clone();
  const currentWarmColor = theme.palette.warmColor.clone();
  let currentStructureOpacity = STRUCTURE_OPACITY * theme.palette.particleOpacityScale;
  let currentAccentOpacity = ACCENT_OPACITY * theme.palette.particleOpacityScale;

  return {
    render(elapsedSeconds: number, deltaSeconds: number): void {
      const palette = theme.palette;

      approachColor(currentLineColor, palette.particleColor, deltaSeconds);
      structureMaterial.color.copy(currentLineColor);
      accentMaterial.color.copy(currentLineColor);
      waterField.setColor(currentLineColor);
      approachColor(currentWarmColor, palette.warmColor, deltaSeconds);

      currentStructureOpacity = approachScalar(
        currentStructureOpacity,
        STRUCTURE_OPACITY * palette.particleOpacityScale,
        deltaSeconds,
      );
      currentAccentOpacity = approachScalar(
        currentAccentOpacity,
        ACCENT_OPACITY * palette.particleOpacityScale,
        deltaSeconds,
      );
      accentMaterial.opacity = currentAccentOpacity;
      waterField.setOpacity(WATER_OPACITY * palette.particleOpacityScale);
      waterField.update(deltaSeconds);

      // Construction scrub: how far the section has scrolled through the
      // viewport, smoothed so scrubbing never snaps.
      const rect = track?.getBoundingClientRect();
      const rawProgress = rect
        ? clamp01((window.innerHeight - rect.top) / (window.innerHeight * 0.9 + rect.height * 0.5))
        : 0;
      smoothProgress = approachScalar(smoothProgress, rawProgress, deltaSeconds);

      const pylonRise = subProgress(PYLON_RISE_START, PYLON_RISE_END, smoothProgress);
      pylonLeft.scale.y = pylonRise;
      pylonRight.scale.y = pylonRise;

      const cableReveal = subProgress(CABLE_DRAW_START, CABLE_DRAW_END, smoothProgress);
      const cableCount = Math.floor(CABLE_POINT_COUNT * cableReveal);
      cableGeometryLeft.setDrawRange(0, cableCount);
      cableGeometryRight.setDrawRange(0, cableCount);

      for (const hanger of hangers) {
        const target = smoothProgress >= hanger.revealThreshold ? 1 : 0;
        hanger.opacity = approachScalar(hanger.opacity, target, deltaSeconds);
        hanger.material.color.copy(currentLineColor);
        hanger.material.opacity = currentStructureOpacity * hanger.opacity;
      }

      const deckReveal = subProgress(DECK_DRAW_START, DECK_DRAW_END, smoothProgress);
      deckGroupLeft.scale.x = deckReveal;
      deckGroupRight.scale.x = deckReveal;
      structureMaterial.opacity = currentStructureOpacity;
      const centerLineCount = Math.floor(CENTERLINE_POINT_COUNT * deckReveal);
      centerLineGeometryLeft.setDrawRange(0, centerLineCount);
      centerLineGeometryRight.setDrawRange(0, centerLineCount);

      // Camera tracking shot: cameraBase is mutated here, then applied
      // directly — createPointerParallax()'s update() only takes over
      // camera.position/lookAt for hover-capable, fine-pointer visitors (see
      // core.ts), so this scroll-driven dolly has to be set unconditionally
      // first; parallax.update() below layers its pointer offset on top for
      // the visitors it supports, and is a no-op everywhere else.
      cameraBase.x = THREE.MathUtils.lerp(CAMERA_X_START, CAMERA_X_END, smoothProgress);
      camera.position.set(cameraBase.x, cameraBase.y, cameraBase.z);
      camera.lookAt(cameraBase.x, cameraBase.y, 0);
      parallax.update();

      // Signal traveler: hidden until the span is built, then a repeating
      // cycle — cross the deck, warming near arrival, then a soft warm
      // pulse at the right pylon.
      const travelerGateOpen = smoothProgress > TRAVELER_GATE_PROGRESS;
      const cycleSeconds = elapsedSeconds % SIGNAL_INTERVAL_SECONDS;
      if (travelerGateOpen && cycleSeconds < SIGNAL_TRAVEL_SECONDS) {
        const travelProgress = cycleSeconds / SIGNAL_TRAVEL_SECONDS;
        travelerPositionAt(travelProgress, travelerScratch);
        traveler.position.copy(travelerScratch);
        traveler.visible = true;
        traveler.scale.setScalar(1);
        const warmBlend = smoothstep(SIGNAL_WARM_START, 1, travelProgress);
        travelerColorScratch.copy(currentLineColor).lerp(currentWarmColor, warmBlend);
        travelerMaterial.color.copy(travelerColorScratch);
        travelerMaterial.opacity = palette.particleOpacityScale;

        for (const trail of trailPoints) {
          const trailProgress = travelProgress - trail.lag;
          if (trailProgress < 0) {
            trail.mesh.visible = false;
            continue;
          }
          travelerPositionAt(trailProgress, travelerScratch);
          trail.mesh.position.copy(travelerScratch);
          trail.mesh.visible = true;
          const trailWarmBlend = smoothstep(SIGNAL_WARM_START, 1, trailProgress);
          travelerColorScratch.copy(currentLineColor).lerp(currentWarmColor, trailWarmBlend);
          trail.material.color.copy(travelerColorScratch);
          trail.material.opacity =
            palette.particleOpacityScale * (1 - trail.lag / (TRAIL_COUNT * TRAIL_SPACING + 0.01));
        }
      } else if (travelerGateOpen && cycleSeconds < SIGNAL_TRAVEL_SECONDS + SIGNAL_PULSE_SECONDS) {
        const pulseProgress = (cycleSeconds - SIGNAL_TRAVEL_SECONDS) / SIGNAL_PULSE_SECONDS;
        traveler.position.copy(rightPylonPoint);
        traveler.visible = true;
        traveler.scale.setScalar(1 + pulseProgress * SIGNAL_PULSE_GROWTH);
        travelerMaterial.color.copy(currentWarmColor);
        travelerMaterial.opacity = (1 - pulseProgress) * palette.particleOpacityScale;
        for (const trail of trailPoints) {
          trail.mesh.visible = false;
        }
      } else {
        traveler.visible = false;
        for (const trail of trailPoints) {
          trail.mesh.visible = false;
        }
      }

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
      pylonBoxGeometry.dispose();
      pylonEdges.dispose();
      crossbeamBoxGeometry.dispose();
      crossbeamEdges.dispose();
      structureMaterial.dispose();

      cableGeometryLeft.dispose();
      cableGeometryRight.dispose();
      accentMaterial.dispose();

      for (const hanger of hangers) {
        hanger.geometry.dispose();
        hanger.material.dispose();
      }

      deckHalfBoxLeft.dispose();
      deckHalfBoxRight.dispose();
      deckEdgesLeft.dispose();
      deckEdgesRight.dispose();
      centerLineGeometryLeft.dispose();
      centerLineGeometryRight.dispose();

      waterField.dispose();

      travelerGeometry.dispose();
      travelerMaterial.dispose();
      for (const trail of trailPoints) {
        trail.material.dispose();
      }

      renderPass.dispose();
      bloomPass.dispose();
      parallax.dispose();
    },
  };
}
