// Spatial Future scene: a wireframe pair of glasses the visitor can drag to
// any angle, with a small signal point periodically tracing the frame and
// neural pathways firing inside each temple — the same "sense, reason,
// render" pipeline metaphor as hero.ts/phone.ts, rendered on hardware that
// SpatialFuture.astro's copy is careful to frame as a possibility, not a
// product. Mounted by scenes/index.ts via core.ts's mountScene() once
// quality-gate.ts's webglAllowed() and the stage's [data-scene="glasses"]
// container both agree it should run.
import { EffectComposer } from "three/examples/jsm/postprocessing/EffectComposer.js";
import { RenderPass } from "three/examples/jsm/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "three/examples/jsm/postprocessing/UnrealBloomPass.js";
// `THREE` itself arrives as a value on SceneContext, so anything needed in a
// type position is imported by name here rather than as a namespace.
import type { BufferGeometry, Vector3 } from "three";
import {
  approachColor,
  approachScalar,
  createDragOrbit,
  createNeuralPathways,
  createPointerParallax,
  type NeuralPathways,
  type SceneContext,
  type SceneInstance,
} from "./core";

const CAMERA_BASE_Z = 3.2;

// Frame proportions, unscaled — then the whole group is scaled down by
// GLASSES_SCALE (below) to comfortably fit the ~32deg-fov frustum at
// CAMERA_BASE_Z across the stage's narrowest expected aspect ratio (the
// desktop layout's near-square stage; see SpatialFuture.module.scss). The
// model is now dragged to arbitrary angles, so the widest axis (x) still
// governs the fit — nothing added below reaches past it.
const LENS_RADIUS = 0.55;
const LENS_TUBE = 0.012;
const LENS_INNER_RADIUS = LENS_RADIUS - 0.07;
const LENS_INNER_TUBE = 0.005;
const LENS_INNER_Z = 0.015;
const LENS_OFFSET_X = 0.62;
const HINGE_X = LENS_OFFSET_X + LENS_RADIUS;
const TEMPLE_TIP_X = HINGE_X + 0.45;
const TEMPLE_TIP_Y = 0.05;
const TEMPLE_TIP_Z = 0.6;
const HINGE_RADIUS = 0.04;
const BROWLINE_WIDTH = HINGE_X * 2;
const BROWLINE_Y = LENS_RADIUS + 0.15;
const GLASSES_SCALE = 0.42;

// Ear bend: where each temple stops running straight back and curls down
// behind the ear. Only reachable visually now that the model turns freely.
const EAR_END_X = TEMPLE_TIP_X - 0.04;
const EAR_END_Y = TEMPLE_TIP_Y - 0.3;
const EAR_END_Z = TEMPLE_TIP_Z + 0.24;
const TEMPLE_CURVE_SAMPLES = 24;

// Temple electronics: one wireframe block per arm, long along the temple's
// own axis (the box is oriented by lookAt(), so its depth is that axis).
const ELECTRONICS_WIDTH = 0.05;
const ELECTRONICS_HEIGHT = 0.045;
const ELECTRONICS_LENGTH = 0.34;

// Bone-conduction grille: three short slots on the inner face of each temple,
// just ahead of the ear bend.
const GRILLE_SLOT_COUNT = 3;
const GRILLE_SLOT_LENGTH = 0.09;
const GRILLE_SLOT_SPACING = 0.035;
const GRILLE_X = TEMPLE_TIP_X - 0.03;
const GRILLE_Y = TEMPLE_TIP_Y - 0.12;
const GRILLE_Z = TEMPLE_TIP_Z + 0.1;

// Sensing cluster on the right browline: a camera ring with its sensor, and a
// depth emitter inboard of it.
const CAMERA_RING_RADIUS = 0.05;
const CAMERA_RING_TUBE = 0.008;
const CAMERA_X = HINGE_X - 0.16;
const CAMERA_Z = 0.04;
const CAMERA_SENSOR_RADIUS = 0.018;
const EMITTER_RADIUS = 0.02;
const EMITTER_X = HINGE_X - 0.34;

// Nose pads, sitting inboard and below each lens' inner edge. Deliberately
// small: they are the only solid mesh at this end of the frame, so anything
// larger reads as a blob against the surrounding line-art.
const NOSE_PAD_RADIUS = 0.032;
const NOSE_PAD_X = 0.13;
const NOSE_PAD_Y = -0.28;
const NOSE_PAD_Z = 0.1;

const ROTATION_SPEED_Y = 0.15; // rad/s, "stately" — the idle spin drag eases back into

const LINE_BASE_OPACITY = 0.55;
const LENS_BASE_OPACITY = 0.7;

const SHIMMER_COUNT = 150;
const SHIMMER_JITTER = 0.05;
const SHIMMER_BASE_OPACITY = 0.4;
const SHIMMER_BREATHE_PERIOD_SECONDS = 5;

// Neural pathways inside each temple's electronics block — see core.ts's
// createNeuralPathways(). Kept tight against the arm so they read as the
// device thinking, not as loose particles around it.
const NEURAL_BRANCH_COUNT = 5;
const NEURAL_JOINTS_PER_BRANCH = 3;
const NEURAL_SAMPLES_PER_BRANCH = 12;
const NEURAL_NODE_SIZE = 0.02;
const NEURAL_PULSE_SIZE = 0.035;
const NEURAL_PULSE_SPEED = 0.4;

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

  // The two temples are mirror images; every per-arm component below is built
  // once per side from this.
  const SIDES = [-1, 1];

  // --- Lens rings (a torus pair, not lines — reads cleaner rotating in 3D
  // than a flat circle), each with a thinner inner rim for lens thickness ----
  const lensMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const lensGeometry = new THREE.TorusGeometry(LENS_RADIUS, LENS_TUBE, 8, 48);
  const lensInnerGeometry = new THREE.TorusGeometry(LENS_INNER_RADIUS, LENS_INNER_TUBE, 6, 40);
  for (const side of SIDES) {
    const rim = new THREE.Mesh(lensGeometry, lensMaterial);
    rim.position.x = side * LENS_OFFSET_X;
    const innerRim = new THREE.Mesh(lensInnerGeometry, lensMaterial);
    innerRim.position.set(side * LENS_OFFSET_X, 0, LENS_INNER_Z);
    glassesGroup.add(rim, innerRim);
  }

  // --- Nose pads ------------------------------------------------------------
  const nosePadGeometry = new THREE.SphereGeometry(NOSE_PAD_RADIUS, 10, 10);
  for (const side of SIDES) {
    const nosePad = new THREE.Mesh(nosePadGeometry, lensMaterial);
    nosePad.position.set(side * NOSE_PAD_X, NOSE_PAD_Y, NOSE_PAD_Z);
    nosePad.scale.set(0.6, 1.4, 0.8);
    glassesGroup.add(nosePad);
  }

  // --- Structural line-art: temples + browline (shared material — both are
  // resting frame, not the signal) -------------------------------------------
  const structureMaterial = new THREE.LineBasicMaterial({
    transparent: true,
    opacity: LINE_BASE_OPACITY,
  });

  // Each temple is one smooth run: hinge -> straight back -> down behind the
  // ear. The straight leg's midpoint doubles as the electronics block's seat
  // and its neural network's origin.
  const templeGeometries: BufferGeometry[] = [];
  const electronicsMidpoints: Vector3[] = [];
  for (const side of SIDES) {
    const hinge = new THREE.Vector3(side * HINGE_X, 0, 0);
    const tip = new THREE.Vector3(side * TEMPLE_TIP_X, TEMPLE_TIP_Y, TEMPLE_TIP_Z);
    const earEnd = new THREE.Vector3(side * EAR_END_X, EAR_END_Y, EAR_END_Z);
    const templeGeometry = new THREE.BufferGeometry().setFromPoints(
      new THREE.CatmullRomCurve3([hinge, tip, earEnd]).getPoints(TEMPLE_CURVE_SAMPLES),
    );
    templeGeometries.push(templeGeometry);
    glassesGroup.add(new THREE.Line(templeGeometry, structureMaterial));
    electronicsMidpoints.push(new THREE.Vector3().addVectors(hinge, tip).multiplyScalar(0.5));
  }

  const browlineBoxGeometry = new THREE.BoxGeometry(BROWLINE_WIDTH, 0.05, 0.03);
  const browlineGeometry = new THREE.EdgesGeometry(browlineBoxGeometry);
  const browline = new THREE.LineSegments(browlineGeometry, structureMaterial);
  browline.position.y = BROWLINE_Y;
  glassesGroup.add(browline);

  // --- Temple electronics: a wireframe block per arm, aimed down the temple
  // by lookAt() so its long axis follows the arm rather than the world z ------
  const electronicsBoxGeometry = new THREE.BoxGeometry(
    ELECTRONICS_WIDTH,
    ELECTRONICS_HEIGHT,
    ELECTRONICS_LENGTH,
  );
  const electronicsGeometry = new THREE.EdgesGeometry(electronicsBoxGeometry);
  for (const [index, side] of SIDES.entries()) {
    const midpoint = electronicsMidpoints.at(index);
    if (!midpoint) {
      continue;
    }
    const block = new THREE.LineSegments(electronicsGeometry, structureMaterial);
    block.position.copy(midpoint);
    block.lookAt(side * TEMPLE_TIP_X, TEMPLE_TIP_Y, TEMPLE_TIP_Z);
    glassesGroup.add(block);
  }

  // --- Bone-conduction grille: three slots on the inner face of each temple -
  const grillePositions = new Float32Array(GRILLE_SLOT_COUNT * 2 * 3);
  const grilleAttribute = new THREE.BufferAttribute(grillePositions, 3);
  for (let slot = 0; slot < GRILLE_SLOT_COUNT; slot += 1) {
    const y = (slot - (GRILLE_SLOT_COUNT - 1) / 2) * GRILLE_SLOT_SPACING;
    grilleAttribute.setXYZ(slot * 2, 0, y, -GRILLE_SLOT_LENGTH / 2);
    grilleAttribute.setXYZ(slot * 2 + 1, 0, y, GRILLE_SLOT_LENGTH / 2);
  }
  const grilleGeometry = new THREE.BufferGeometry();
  grilleGeometry.setAttribute("position", grilleAttribute);
  for (const side of SIDES) {
    const grille = new THREE.LineSegments(grilleGeometry, structureMaterial);
    grille.position.set(side * GRILLE_X, GRILLE_Y, GRILLE_Z);
    glassesGroup.add(grille);
  }

  // --- Bridge: a small curve connecting the two lenses' inner edges,
  // reused below as the middle leg of the signal traveler's path ------------
  const bridgeCurve = new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(-LENS_OFFSET_X + LENS_RADIUS, 0, 0),
    new THREE.Vector3(0, -0.05, 0.15),
    new THREE.Vector3(LENS_OFFSET_X - LENS_RADIUS, 0, 0),
  );
  const bridgeGeometry = new THREE.BufferGeometry().setFromPoints(bridgeCurve.getPoints(16));
  glassesGroup.add(new THREE.Line(bridgeGeometry, structureMaterial));

  // --- Camera ring: structural rim, warm sensor at its centre ---------------
  const cameraRingGeometry = new THREE.TorusGeometry(CAMERA_RING_RADIUS, CAMERA_RING_TUBE, 8, 24);
  const cameraRing = new THREE.Mesh(cameraRingGeometry, lensMaterial);
  cameraRing.position.set(CAMERA_X, BROWLINE_Y, CAMERA_Z);
  glassesGroup.add(cameraRing);

  // --- Warm accents: hinges, the camera sensor, and the depth emitter — the
  // three points where the world actually enters or leaves the frame --------
  const accentMaterial = new THREE.MeshBasicMaterial({ transparent: true });
  const hingeGeometry = new THREE.SphereGeometry(HINGE_RADIUS, 12, 12);
  for (const side of SIDES) {
    const hinge = new THREE.Mesh(hingeGeometry, accentMaterial);
    hinge.position.x = side * HINGE_X;
    glassesGroup.add(hinge);
  }

  const cameraSensorGeometry = new THREE.SphereGeometry(CAMERA_SENSOR_RADIUS, 10, 10);
  const cameraSensor = new THREE.Mesh(cameraSensorGeometry, accentMaterial);
  cameraSensor.position.set(CAMERA_X, BROWLINE_Y, CAMERA_Z + 0.01);
  glassesGroup.add(cameraSensor);

  const emitterGeometry = new THREE.SphereGeometry(EMITTER_RADIUS, 10, 10);
  const emitter = new THREE.Mesh(emitterGeometry, accentMaterial);
  emitter.position.set(EMITTER_X, BROWLINE_Y, CAMERA_Z);
  glassesGroup.add(emitter);

  // --- Neural pathways: one small network per temple, seated in that arm's
  // electronics block — the reasoning half of the same pipeline the signal
  // traveler below carries across the frame ---------------------------------
  const pathwayNetworks: NeuralPathways[] = [];
  for (const midpoint of electronicsMidpoints) {
    const network = createNeuralPathways({
      branchCount: NEURAL_BRANCH_COUNT,
      origin: midpoint,
      reach: new THREE.Vector3(0.09, 0.09, 0.26),
      jointsPerBranch: NEURAL_JOINTS_PER_BRANCH,
      samplesPerBranch: NEURAL_SAMPLES_PER_BRANCH,
      nodeSize: NEURAL_NODE_SIZE,
      pulseSize: NEURAL_PULSE_SIZE,
      pulseSpeed: NEURAL_PULSE_SPEED,
    });
    pathwayNetworks.push(network);
    glassesGroup.add(network.object);
  }

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

  // Drag owns the group's yaw/pitch outright, so parallax is left with the
  // camera only (no tilt targets) — otherwise the two would write the same
  // rotation channels every frame and fight.
  const orbit = createDragOrbit(container, glassesGroup, ROTATION_SPEED_Y);
  const parallax = createPointerParallax(container, camera, cameraBase);

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
  let currentAccentOpacity = theme.palette.emissiveIntensity;

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
      accentMaterial.color.copy(currentWarmColor);
      currentAccentOpacity = approachScalar(
        currentAccentOpacity,
        palette.emissiveIntensity,
        deltaSeconds,
      );
      accentMaterial.opacity = currentAccentOpacity;

      for (const network of pathwayNetworks) {
        network.setTraceColor(currentLineColor);
        network.setPulseColor(currentWarmColor);
        network.setOpacity(currentLineOpacity);
        network.update(deltaSeconds);
      }

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

      // Drag-to-orbit: while the pointer is down it sets the group's yaw and
      // pitch directly; on release the flick's momentum eases back into the
      // idle spin. parallax.update() only moves the camera here.
      orbit.update(deltaSeconds);
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
      lensGeometry.dispose();
      lensInnerGeometry.dispose();
      nosePadGeometry.dispose();
      lensMaterial.dispose();
      templeGeometries.forEach((geometry) => {
        geometry.dispose();
      });
      browlineBoxGeometry.dispose();
      browlineGeometry.dispose();
      electronicsBoxGeometry.dispose();
      electronicsGeometry.dispose();
      grilleGeometry.dispose();
      structureMaterial.dispose();
      bridgeGeometry.dispose();
      cameraRingGeometry.dispose();
      hingeGeometry.dispose();
      cameraSensorGeometry.dispose();
      emitterGeometry.dispose();
      accentMaterial.dispose();
      travelerGeometry.dispose();
      travelerMaterial.dispose();
      shimmerGeometry.dispose();
      shimmerMaterial.dispose();
      pathwayNetworks.forEach((network) => {
        network.dispose();
      });
      renderPass.dispose();
      bloomPass.dispose();
      orbit.dispose();
      parallax.dispose();
    },
  };
}
