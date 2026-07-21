// Shared engine every "First Light" 3D scene (hero.ts, ambient.ts, and future
// scenes) mounts through: canvas/renderer lifecycle, the theme adapter, a
// drifting point-field builder, and the pointer-parallax helper. Only ever
// reached via scenes/index.ts after quality-gate.ts's webglAllowed() passes —
// safe to import `three` statically here.
import * as THREE from "three";

export type ThemeName = "light" | "dark";

// Palette a scene reads each frame to answer "what should this look like
// right now" — never a reason to rebuild a material, only to lerp toward.
// Hex values mirror src/styles/abstracts/_tokens.scss's accent-primary/
// accent-warm dark & light entries; kept as plain hex here (not read from
// CSS custom properties) since these feed THREE.Color, not the DOM.
export interface ScenePalette {
  bloom: boolean;
  particleColor: THREE.Color;
  warmColor: THREE.Color;
  particleOpacityScale: number;
  emissiveIntensity: number;
}

const PALETTES: Record<ThemeName, ScenePalette> = {
  dark: {
    bloom: true,
    particleColor: new THREE.Color("#5eb1ff"),
    warmColor: new THREE.Color("#ffb37a"),
    particleOpacityScale: 1,
    emissiveIntensity: 1,
  },
  light: {
    bloom: false,
    particleColor: new THREE.Color("#145fc4"),
    warmColor: new THREE.Color("#a8480d"),
    particleOpacityScale: 0.5,
    emissiveIntensity: 0.15,
  },
};

function readTheme(): ThemeName {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

// Watches <html data-theme> (set by BaseLayout.astro's no-flash script /
// Header.astro's toggle) so scenes can lerp toward a new palette instead of
// snapping or rebuilding materials on theme change.
export class ThemeAdapter {
  private observer: MutationObserver;
  private current: ThemeName;

  constructor() {
    this.current = readTheme();
    this.observer = new MutationObserver(() => {
      this.current = readTheme();
    });
    this.observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"],
    });
  }

  get palette(): ScenePalette {
    return PALETTES[this.current];
  }

  dispose(): void {
    this.observer.disconnect();
  }
}

// Exponential approach: reaches ~95% of the distance to `target` after
// THEME_LERP_SECONDS regardless of frame rate — how scenes ease a material
// color/intensity toward a new theme palette over "~400ms" per the plan,
// without ever rebuilding the material.
const THEME_LERP_SECONDS = 0.4;
const THEME_LERP_TAU = THEME_LERP_SECONDS / 3;

export function approachColor(
  current: THREE.Color,
  target: THREE.Color,
  deltaSeconds: number,
): void {
  current.lerp(target, 1 - Math.exp(-deltaSeconds / THEME_LERP_TAU));
}

export function approachScalar(current: number, target: number, deltaSeconds: number): number {
  return current + (target - current) * (1 - Math.exp(-deltaSeconds / THEME_LERP_TAU));
}

// --- Scene lifecycle ---------------------------------------------------

export interface SceneContext {
  three: typeof THREE;
  renderer: THREE.WebGLRenderer;
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  container: HTMLElement;
  theme: ThemeAdapter;
}

export interface SceneInstance {
  // Called once per rendered frame (never while offscreen/hidden/tab-backgrounded).
  // Responsible for its own final draw call (renderer.render or a composer).
  render(elapsedSeconds: number, deltaSeconds: number): void;
  resize?(width: number, height: number): void;
  dispose(): void;
}

export type SceneFactory = (ctx: SceneContext) => SceneInstance;

export interface MountedScene {
  dispose(): void;
}

// Mounts one `[data-scene]` container: creates its canvas, builds the scene
// via `factory`, drives a paused-when-hidden rAF loop, and hands back a
// dispose() that frees everything. Marks the container `.scene-active` once
// live so CSS can fade redundant static art (Hero.module.scss); un-marks it
// again on context loss so that static art returns.
export function mountScene(container: HTMLElement, factory: SceneFactory): MountedScene {
  const canvas = document.createElement("canvas");
  canvas.setAttribute("aria-hidden", "true");
  canvas.setAttribute("focusable", "false");
  canvas.style.position = "absolute";
  canvas.style.inset = "0";
  canvas.style.width = "100%";
  canvas.style.height = "100%";
  canvas.style.pointerEvents = "none";
  // Inserted first, not appended: every scene's canvas renders behind
  // whatever static CSS/SVG art already lives in `container` (DOM order is
  // the only stacking rule the existing layers rely on — see Hero.astro).
  container.insertBefore(canvas, container.firstChild);

  let renderer: THREE.WebGLRenderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  } catch {
    canvas.remove();
    return { dispose: () => undefined };
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 100);
  const theme = new ThemeAdapter();
  const instance = factory({ three: THREE, renderer, scene, camera, container, theme });

  const applySize = (): void => {
    const rect = container.getBoundingClientRect();
    const width = Math.max(1, rect.width);
    const height = Math.max(1, rect.height);
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    instance.resize?.(width, height);
  };
  applySize();

  const resizeObserver = new ResizeObserver(applySize);
  resizeObserver.observe(container);

  let inView = false;
  const intersectionObserver = new IntersectionObserver((entries) => {
    const lastEntry = entries.at(-1);
    inView = lastEntry?.isIntersecting ?? false;
  });
  intersectionObserver.observe(container);

  let documentVisible = document.visibilityState === "visible";
  const handleVisibilityChange = (): void => {
    documentVisible = document.visibilityState === "visible";
  };
  document.addEventListener("visibilitychange", handleVisibilityChange);

  const startTime = performance.now();
  let lastTime = startTime;
  let rafId = 0;
  const loop = (time: number): void => {
    rafId = requestAnimationFrame(loop);
    const deltaSeconds = Math.min((time - lastTime) / 1000, 0.1);
    lastTime = time;
    if (!inView || !documentVisible) {
      return;
    }
    instance.render((time - startTime) / 1000, deltaSeconds);
  };
  rafId = requestAnimationFrame(loop);

  container.classList.add("scene-active");

  const dispose = (): void => {
    cancelAnimationFrame(rafId);
    resizeObserver.disconnect();
    intersectionObserver.disconnect();
    document.removeEventListener("visibilitychange", handleVisibilityChange);
    canvas.removeEventListener("webglcontextlost", handleContextLost);
    theme.dispose();
    instance.dispose();
    renderer.dispose();
    canvas.remove();
  };

  function handleContextLost(event: Event): void {
    event.preventDefault();
    container.classList.remove("scene-active");
    dispose();
  }
  canvas.addEventListener("webglcontextlost", handleContextLost);

  return { dispose };
}

// --- Drifting point field ------------------------------------------------

export interface PointFieldOptions {
  count: number;
  // Points drift within a cube of this half-extent, wrapping at the edges.
  spread: number;
  baseSize: number;
  // Fraction of baseSize randomized per point (0 = uniform, 1 = 0..2x).
  sizeVariation: number;
  additive: boolean;
}

export interface PointField {
  points: THREE.Points;
  setColor(color: THREE.Color): void;
  setOpacity(opacity: number): void;
  update(deltaSeconds: number): void;
  dispose(): void;
}

// Custom-shader point field: THREE.PointsMaterial has no per-vertex size, so
// "subtle per-point size variation" needs a `size` attribute + a small vertex
// shader (the standard three.js pattern for this). Shared by hero.ts's depth
// field and ambient.ts's page-wide field.
export function createPointField(options: PointFieldOptions): PointField {
  const { count, spread, baseSize, sizeVariation, additive } = options;
  const positions = new Float32Array(count * 3);
  const sizes = new Float32Array(count);
  const drift = new Float32Array(count * 3);

  for (let i = 0; i < count; i += 1) {
    positions[i * 3] = (Math.random() - 0.5) * spread * 2;
    positions[i * 3 + 1] = (Math.random() - 0.5) * spread * 2;
    positions[i * 3 + 2] = (Math.random() - 0.5) * spread * 2;
    // `i` is a loop counter bounded by `count`, not attacker-controlled input.
    // eslint-disable-next-line security/detect-object-injection
    sizes[i] = baseSize * (1 - sizeVariation / 2 + Math.random() * sizeVariation);
    drift[i * 3] = (Math.random() - 0.5) * 0.02;
    drift[i * 3 + 1] = (Math.random() - 0.5) * 0.02;
    drift[i * 3 + 2] = (Math.random() - 0.5) * 0.02;
  }

  const geometry = new THREE.BufferGeometry();
  const positionAttribute = new THREE.BufferAttribute(positions, 3);
  geometry.setAttribute("position", positionAttribute);
  geometry.setAttribute("size", new THREE.BufferAttribute(sizes, 1));

  // Kept as its own reference (rather than read back off `material.uniforms`
  // below) since `ShaderMaterial.uniforms` is typed as a generic
  // `{ [uniform: string]: IUniform }` index signature — under
  // `noUncheckedIndexedAccess`, reading a named uniform back off it would
  // widen to `IUniform | undefined`.
  const uniforms = {
    uColor: { value: new THREE.Color("#5eb1ff") },
    uOpacity: { value: 1 },
  };

  const material = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: `
      attribute float size;
      void main() {
        vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = size * (300.0 / -mvPosition.z);
        gl_Position = projectionMatrix * mvPosition;
      }
    `,
    fragmentShader: `
      uniform vec3 uColor;
      uniform float uOpacity;
      void main() {
        float dist = length(gl_PointCoord - vec2(0.5));
        if (dist > 0.5) discard;
        gl_FragColor = vec4(uColor, (1.0 - dist * 2.0) * uOpacity);
      }
    `,
    transparent: true,
    depthWrite: false,
    blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
  });

  const points = new THREE.Points(geometry, material);
  const DRIFT_SCALE = 10;

  return {
    points,
    setColor(color: THREE.Color): void {
      uniforms.uColor.value.copy(color);
    },
    setOpacity(opacity: number): void {
      uniforms.uOpacity.value = opacity;
    },
    update(deltaSeconds: number): void {
      const array = positionAttribute.array as Float32Array;
      // `i` below is a loop counter bounded by `count * 3`, not
      // attacker-controlled input.
      for (let i = 0; i < count * 3; i += 1) {
        // eslint-disable-next-line security/detect-object-injection
        const current = array[i] ?? 0;
        // eslint-disable-next-line security/detect-object-injection
        const velocity = drift[i] ?? 0;
        let next = current + velocity * deltaSeconds * DRIFT_SCALE;
        const axisSpread = spread;
        if (next > axisSpread) {
          next = -axisSpread;
        } else if (next < -axisSpread) {
          next = axisSpread;
        }
        // eslint-disable-next-line security/detect-object-injection
        array[i] = next;
      }
      positionAttribute.needsUpdate = true;
    },
    dispose(): void {
      geometry.dispose();
      material.dispose();
    },
  };
}

// --- Pointer parallax -----------------------------------------------------

const CAMERA_OFFSET_FACTOR = 0.04;
const POINTER_LERP_RATE = 0.08;
const OBJECT_ROTATION_LERP_RATE = 0.06;
const MAX_OBJECT_TILT_RADIANS = 0.12;

export interface PointerParallax {
  update(): void;
  dispose(): void;
}

// Camera-follows-cursor parallax, plus an optional subtle tilt on scene
// objects (e.g. hero's icosphere) — hover-capable + fine-pointer only, same
// gate as the rest of the site's pointer-reactive motion (see
// initHeroPointerGlow/initMagneticCta in src/scripts/motion.ts). Returns a
// no-op everywhere else so callers can invoke update() unconditionally.
export function createPointerParallax(
  container: HTMLElement,
  camera: THREE.PerspectiveCamera,
  cameraBase: THREE.Vector3,
  tiltTargets: THREE.Object3D[] = [],
): PointerParallax {
  if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    return { update: () => undefined, dispose: () => undefined };
  }

  const rawPointer = { x: 0, y: 0 };
  const cameraPointer = { x: 0, y: 0 };
  const tiltPointer = { x: 0, y: 0 };

  const handlePointerMove = (event: PointerEvent): void => {
    const rect = container.getBoundingClientRect();
    rawPointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    rawPointer.y = ((event.clientY - rect.top) / rect.height) * 2 - 1;
  };
  const handlePointerLeave = (): void => {
    rawPointer.x = 0;
    rawPointer.y = 0;
  };
  container.addEventListener("pointermove", handlePointerMove);
  container.addEventListener("pointerleave", handlePointerLeave);

  return {
    update(): void {
      cameraPointer.x += (rawPointer.x - cameraPointer.x) * POINTER_LERP_RATE;
      cameraPointer.y += (rawPointer.y - cameraPointer.y) * POINTER_LERP_RATE;
      camera.position.set(
        cameraBase.x + cameraPointer.x * CAMERA_OFFSET_FACTOR,
        cameraBase.y - cameraPointer.y * CAMERA_OFFSET_FACTOR,
        cameraBase.z,
      );
      camera.lookAt(cameraBase.x, cameraBase.y, 0);

      if (tiltTargets.length > 0) {
        tiltPointer.x += (rawPointer.x - tiltPointer.x) * OBJECT_ROTATION_LERP_RATE;
        tiltPointer.y += (rawPointer.y - tiltPointer.y) * OBJECT_ROTATION_LERP_RATE;
        for (const object of tiltTargets) {
          object.rotation.x = tiltPointer.y * MAX_OBJECT_TILT_RADIANS;
          object.rotation.z = -tiltPointer.x * MAX_OBJECT_TILT_RADIANS;
        }
      }
    },
    dispose(): void {
      container.removeEventListener("pointermove", handlePointerMove);
      container.removeEventListener("pointerleave", handlePointerLeave);
    },
  };
}
