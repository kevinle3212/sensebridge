// Single client-side entry point for the site's scroll/reveal motion layer
// (Phase 5). Loaded once from BaseLayout.astro.
//
// Two-layer reduced-motion gate, JS half (see src/styles/abstracts/_motion.scss
// for the CSS half): everything below lives inside gsap.matchMedia() keyed to
// "(prefers-reduced-motion: no-preference)". Under `reduce`, this file
// instantiates nothing — no Lenis, no ScrollTrigger, no gsap.set/to calls,
// native scroll only, and every section renders exactly as it does with JS
// disabled entirely.
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import Lenis from "lenis";

export {};

gsap.registerPlugin(ScrollTrigger);

// Mirror --duration-fast/base/slow/slower from src/styles/abstracts/_motion.scss
// (GSAP needs numeric seconds; the CSS custom properties are for CSS
// transitions, not this file).
const DURATION_FAST = 0.12;
const DURATION_BASE = 0.24;
const DURATION_SLOW = 0.4;
const DURATION_SLOWER = 0.7;
// Mirrors --ease-out-expo ("reveals" per _motion.scss). GSAP's built-in
// "expo.out" is the standard named curve for that easing family.
const EASE_REVEAL = "expo.out";
// Mirrors --ease-in-out ("sweeps" per _motion.scss, cubic-bezier(0.65, 0,
// 0.35, 1)). GSAP's built-in "power2.inOut" is the standard named curve for
// that same cubic-inOut shape.
const EASE_SWEEP = "power2.inOut";

// How far each hero-visual depth layer travels (px) as the hero section
// scrolls past, back to front: glow moves least, the sensing field most.
const HERO_PARALLAX_DISTANCE: Record<string, number> = {
  glow: 20,
  device: 40,
  field: 70,
};

const mm = gsap.matchMedia();

mm.add("(prefers-reduced-motion: no-preference)", () => {
  // Lenis 1.1.13+ defaults to driving its own rAF loop (`autoRaf: true`);
  // disable it so gsap.ticker is the single rAF driver, per the plan's
  // Lenis+ScrollTrigger wiring.
  const lenis = new Lenis({ autoRaf: false });
  const driveLenis = (time: number): void => {
    lenis.raf(time * 1000);
  };

  lenis.on("scroll", () => {
    ScrollTrigger.update();
  });
  gsap.ticker.add(driveLenis);
  gsap.ticker.lagSmoothing(0);

  initHeroReveal();
  initHeroParallax();
  initSignalBridge();
  initBridgeEasterEgg();
  initSignalSpine();
  initStageReveals();
  initSectionReveals();
  initPhoneExplodedReveal();
  initSpatialFutureReveal();
  initScrollProgress();
  initMagneticCta();
  initMagneticNav();
  initHeroPointerGlow();

  return () => {
    gsap.ticker.remove(driveLenis);
    lenis.destroy();
  };
});

// "First light" load choreography: glow blooms in, then the LiDAR field
// ignites, then heading/lede/status/CTA stagger in (unchanged from before),
// then the hero's spine node locks last. The field rings animate their SVG
// `r` (radius) rather than opacity/transform — those two properties are
// already driven forever by the `lidar-pulse` CSS animation
// (Hero.module.scss), and a CSS animation always wins the cascade over a
// same-property inline style, so tweening opacity/transform here would be a
// silent no-op. Radius 0 hides a circle regardless of its opacity, so this
// sidesteps that conflict entirely and leaves the idle pulse untouched.
function initHeroReveal(): void {
  const words = document.querySelectorAll<HTMLElement>("[data-hero-word]");
  const rest = document.querySelectorAll<HTMLElement>("[data-hero-reveal]");
  const heroSection = document.querySelector<HTMLElement>(
    'section[aria-labelledby="hero-heading"]',
  );
  const ring = heroSection?.querySelector<SVGCircleElement>("[data-spine-ring]") ?? null;
  const dot = heroSection?.querySelector<SVGCircleElement>("[data-spine-dot]") ?? null;
  const glow = heroSection?.querySelector<HTMLElement>('[data-hero-layer="glow"]') ?? null;
  const fieldRings = heroSection?.querySelectorAll<SVGCircleElement>("[data-field-ring]") ?? [];
  if (words.length === 0 && rest.length === 0) {
    return;
  }

  const fieldRingRadii = new Map<SVGCircleElement, string>();
  fieldRings.forEach((fieldRing) => {
    fieldRingRadii.set(fieldRing, fieldRing.getAttribute("r") ?? "0");
  });

  gsap.set(words, { opacity: 0, y: "0.6em" });
  gsap.set(rest, { opacity: 0, y: 16 });
  if (ring) {
    gsap.set(ring, { opacity: 0.4 });
  }
  if (dot) {
    gsap.set(dot, { scale: 0 });
  }
  if (glow) {
    gsap.set(glow, { opacity: 0 });
  }
  if (fieldRings.length > 0) {
    gsap.set(fieldRings, { attr: { r: 0 } });
  }

  const timeline = gsap.timeline({ defaults: { ease: EASE_REVEAL, duration: DURATION_SLOW } });

  if (glow) {
    timeline.to(glow, { opacity: 1, duration: DURATION_SLOWER, ease: EASE_SWEEP });
  }
  if (fieldRings.length > 0) {
    timeline.to(
      fieldRings,
      {
        attr: { r: (_index, target) => fieldRingRadii.get(target as SVGCircleElement) ?? "0" },
        duration: DURATION_BASE,
        stagger: 0.06,
      },
      glow ? "-=0.3" : undefined,
    );
  }
  timeline
    .to(words, { opacity: 1, y: 0, stagger: 0.04 }, glow || fieldRings.length > 0 ? "-=0.1" : 0)
    .to(rest, { opacity: 1, y: 0, stagger: 0.08 }, "-=0.2");

  // Signal Spine's "sensing" node (DESIGN.md "Signal Spine") locks in as the
  // hero reveal settles, rather than on its own scroll trigger — it's
  // already on screen at load, same hide-then-reveal pattern as the other
  // four stage nodes in initStageReveals().
  if (ring) {
    timeline.to(ring, { opacity: 1, duration: DURATION_BASE }, "-=0.1");
  }
  if (dot) {
    timeline.to(dot, { scale: 1, duration: DURATION_FAST }, "<");
  }
}

function initHeroParallax(): void {
  const heroSection = document.querySelector<HTMLElement>(
    'section[aria-labelledby="hero-heading"]',
  );
  const layers = document.querySelectorAll<HTMLElement>("[data-hero-layer]");
  if (!heroSection || layers.length === 0) {
    return;
  }

  layers.forEach((layer) => {
    const distance = HERO_PARALLAX_DISTANCE[layer.dataset.heroLayer ?? ""] ?? 30;
    gsap.to(layer, {
      y: distance,
      ease: "none",
      scrollTrigger: {
        trigger: heroSection,
        start: "top top",
        end: "bottom top",
        scrub: true,
      },
    });
  });
}

// Scroll-triggered "construction" sequence for the Signal Bridge visual
// (DESIGN.md → "Signal Bridge"): the cable and deck draw in, cogs rotate
// into a locked position, a Signal Blue pulse crosses the finished deck, and
// the Perception Glow bloom arrives at the far pylon. CSS's resting state is
// already this finished picture — this only ever hides it first (via
// gsap.set, inside the reduced-motion gate) and reveals it once, on scroll.
function initSignalBridge(): void {
  const visual = document.querySelector<HTMLElement>("[data-bridge-visual]");
  if (!visual) {
    return;
  }

  const drawn = visual.querySelectorAll<SVGGeometryElement>(
    "[data-bridge-cable], [data-bridge-suspender], [data-bridge-deck]",
  );
  const cogs = visual.querySelectorAll<SVGUseElement>("[data-bridge-cog]");
  const pulse = visual.querySelector<SVGCircleElement>("[data-bridge-pulse]");
  const glow = visual.querySelector<HTMLElement>("[data-bridge-glow]");

  drawn.forEach((element) => {
    const length = element.getTotalLength();
    gsap.set(element, { strokeDasharray: length, strokeDashoffset: length });
  });
  gsap.set(cogs, { rotate: -90, transformOrigin: "50% 50%" });

  const timeline = gsap.timeline({
    defaults: { ease: EASE_REVEAL },
    scrollTrigger: { trigger: visual, start: "top 80%" },
  });

  timeline
    .to("[data-bridge-cable]", { strokeDashoffset: 0, duration: DURATION_SLOW })
    .to(
      "[data-bridge-suspender]",
      { strokeDashoffset: 0, duration: DURATION_BASE, stagger: 0.08 },
      "-=0.1",
    )
    .to("[data-bridge-deck]", { strokeDashoffset: 0, duration: DURATION_SLOW }, "-=0.15")
    .to(cogs, { rotate: 0, duration: DURATION_BASE, stagger: 0.06 }, "-=0.2");

  if (pulse) {
    timeline.add(crossBridgePulse(pulse));
  }
  if (glow) {
    timeline.fromTo(
      glow,
      { opacity: 0 },
      { opacity: 1, duration: DURATION_SLOW },
      pulse ? "-=0.2" : undefined,
    );
  }
}

// Signal Blue pulse crossing the finished deck (48 → 272, the same two
// pylon x-coordinates as SignalBridge.astro) — shared by the scroll-driven
// construction sequence above and the click-replay easter egg below, so the
// two never drift apart.
function crossBridgePulse(pulse: SVGCircleElement): gsap.core.Timeline {
  return gsap
    .timeline({ defaults: { ease: EASE_REVEAL } })
    .to(pulse, { opacity: 1, duration: DURATION_FAST })
    .to(pulse, { attr: { cx: 272 }, duration: DURATION_SLOWER, ease: "none" })
    .to(pulse, { opacity: 0, duration: DURATION_FAST });
}

// Easter egg (DESIGN.md "Signal Bridge"): clicking the finished bridge
// visual replays its pulse crossing once. Decorative-only — the visual
// stays aria-hidden and this never adds a keyboard handler or tab stop, so
// it carries no information a screen-reader user would otherwise miss (the
// same "signal crossing" story is in the section's prose).
function initBridgeEasterEgg(): void {
  const visual = document.querySelector<HTMLElement>("[data-bridge-visual]");
  const pulse = visual?.querySelector<SVGCircleElement>("[data-bridge-pulse]");
  if (!visual || !pulse) {
    return;
  }

  visual.addEventListener("click", () => {
    gsap.killTweensOf(pulse);
    gsap.set(pulse, { opacity: 0, attr: { cx: 48 } });
    crossBridgePulse(pulse);
  });
}

// Scroll-scrubbed signal pulse traveling down the Signal Spine rail
// (DESIGN.md "Signal Spine"), across its full Hero→#accessibility range.
// The pulse's CSS resting state is opacity 0 in every mode
// (SignalSpine.module.scss) — a travelling dot has no static "finished"
// frame, so under reduced-motion/no-JS it simply never appears.
function initSignalSpine(): void {
  const spine = document.querySelector<HTMLElement>("[data-spine]");
  const pulse = document.querySelector<HTMLElement>("[data-spine-pulse]");
  if (!spine || !pulse) {
    return;
  }

  gsap.set(pulse, { top: 0, opacity: 1 });
  gsap.to(pulse, {
    top: "100%",
    ease: "none",
    scrollTrigger: { trigger: spine, start: "top top", end: "bottom bottom", scrub: true },
  });
}

// Sequenced choreography for the four product-pipeline stage sections below
// the hero (DESIGN.md "Signal Spine"): its Signal Spine node locks in, then
// the section heading reveals, then its body copy staggers in — one
// timeline per section, gated on that section entering view. Follows the
// same hide-then-reveal pattern as initSignalBridge: every gsap.set below
// only ever hides the already-finished resting picture first. The hero's
// own node lock is handled inside initHeroReveal() instead, since the hero
// reveals on load rather than on scroll.
function initStageReveals(): void {
  document.querySelectorAll<HTMLElement>("[data-stage]").forEach((section) => {
    const ring = section.querySelector<SVGCircleElement>("[data-spine-ring]");
    const dot = section.querySelector<SVGCircleElement>("[data-spine-dot]");
    const heading = section.querySelector<HTMLElement>("h2");
    const items = section.querySelectorAll<HTMLElement>("[data-reveal-item]");

    if (ring) {
      gsap.set(ring, { opacity: 0.4 });
    }
    if (dot) {
      gsap.set(dot, { scale: 0 });
    }
    if (heading) {
      gsap.set(heading, { opacity: 0, y: 16 });
    }
    gsap.set(items, { opacity: 0, y: 24 });

    const timeline = gsap.timeline({
      defaults: { ease: EASE_REVEAL },
      scrollTrigger: { trigger: section, start: "top 80%" },
    });

    if (ring) {
      timeline.to(ring, { opacity: 1, duration: DURATION_BASE });
    }
    if (dot) {
      timeline.to(dot, { scale: 1, duration: DURATION_FAST }, "<");
    }
    if (heading) {
      timeline.to(heading, { opacity: 1, y: 0, duration: DURATION_SLOW });
    }
    if (items.length > 0) {
      timeline.to(items, { opacity: 1, y: 0, duration: DURATION_BASE, stagger: 0.08 });
    }
  });
}

// Generic whole-section fade for [data-reveal] sections that aren't part of
// the stage choreography above (currently just "Developed in the open" —
// see FollowProgress.astro). Stage sections carry [data-stage] and are
// handled entirely by initStageReveals() instead.
function initSectionReveals(): void {
  document.querySelectorAll<HTMLElement>("[data-reveal]:not([data-stage])").forEach((section) => {
    gsap.set(section, { opacity: 0, y: 24 });
    gsap.to(section, {
      opacity: 1,
      y: 0,
      duration: DURATION_SLOW,
      ease: EASE_REVEAL,
      scrollTrigger: { trigger: section, start: "top 85%" },
    });
  });
}

// Reveal choreography for the PhoneExploded scrollytelling section
// (PhoneExploded.astro, #device): the header block (h2 + lede) fades/rises
// in once on approach, then each of the three annotation blocks does the
// same independently as it scrolls past the sticky stage. The stage itself
// (canvas/fallback SVG) is never touched here — scripts/scenes/phone.ts owns
// it directly via scroll-rect reads, so animating it here would fight that.
function initPhoneExplodedReveal(): void {
  const section = document.querySelector<HTMLElement>("#device");
  if (!section) {
    return;
  }

  const heading = section.querySelector<HTMLElement>("h2");
  const lede = section.querySelector<HTMLElement>("[data-reveal-item]");
  const header = [heading, lede].filter((el): el is HTMLElement => el !== null);
  if (header.length > 0) {
    gsap.set(header, { opacity: 0, y: 16 });
    gsap.to(header, {
      opacity: 1,
      y: 0,
      duration: DURATION_SLOW,
      ease: EASE_REVEAL,
      scrollTrigger: { trigger: section, start: "top 80%" },
    });
  }

  section.querySelectorAll<HTMLElement>("[data-reveal-block]").forEach((block) => {
    gsap.set(block, { opacity: 0, y: 24 });
    gsap.to(block, {
      opacity: 1,
      y: 0,
      duration: DURATION_SLOW,
      ease: EASE_REVEAL,
      scrollTrigger: { trigger: block, start: "top 85%", once: true },
    });
  });
}

// Reveal choreography for the SpatialFuture epilogue (SpatialFuture.astro,
// #future): kicker, heading, and both paragraphs fade/rise in together with
// a gentle stagger on approach. The wireframe-glasses stage/SVG is never
// touched here — it idles on its own via scripts/scenes/glasses.ts.
function initSpatialFutureReveal(): void {
  const section = document.querySelector<HTMLElement>("#future");
  const items = section?.querySelectorAll<HTMLElement>("[data-reveal-item]");
  if (!items || items.length === 0) {
    return;
  }

  gsap.set(items, { opacity: 0, y: 16 });
  gsap.to(items, {
    opacity: 1,
    y: 0,
    duration: DURATION_SLOW,
    ease: EASE_REVEAL,
    stagger: 0.08,
    scrollTrigger: { trigger: section, start: "top 80%" },
  });
}

// Header scroll-progress bar (Header.astro → [data-scroll-progress]).
// Resting/no-JS/reduced-motion state is width 0 (i.e. absent) — this is the
// only thing that ever gives it width, scrubbed 0%→100% across the whole
// page's scroll range, same trigger shape as initSignalSpine() above.
function initScrollProgress(): void {
  const bar = document.querySelector<HTMLElement>("[data-scroll-progress]");
  if (!bar) {
    return;
  }

  gsap.set(bar, { width: 0 });
  gsap.to(bar, {
    width: "100%",
    ease: "none",
    scrollTrigger: { trigger: document.body, start: "top top", end: "bottom bottom", scrub: true },
  });
}

// Magnetic ghost CTA (Hero.astro → [data-magnetic]): gently pulls the hero
// CTA toward the cursor, springing back on leave. Hover-capable + fine
// pointer only (in addition to the outer reduced-motion gate) — touch
// stays a static button.
function initMagneticCta(): void {
  if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    return;
  }
  const cta = document.querySelector<HTMLElement>("[data-magnetic]");
  if (!cta) {
    return;
  }

  const MAX_OFFSET_PX = 6;
  const moveX = gsap.quickTo(cta, "x", { duration: DURATION_BASE, ease: "power2.out" });
  const moveY = gsap.quickTo(cta, "y", { duration: DURATION_BASE, ease: "power2.out" });

  cta.addEventListener("mousemove", (event) => {
    const rect = cta.getBoundingClientRect();
    const relativeX = event.clientX - (rect.left + rect.width / 2);
    const relativeY = event.clientY - (rect.top + rect.height / 2);
    moveX(gsap.utils.clamp(-MAX_OFFSET_PX, MAX_OFFSET_PX, relativeX * 0.3));
    moveY(gsap.utils.clamp(-MAX_OFFSET_PX, MAX_OFFSET_PX, relativeY * 0.3));
  });

  cta.addEventListener("mouseleave", () => {
    moveX(0);
    moveY(0);
  });
}

// Magnetic header nav links (Header.astro → [data-magnetic-nav]): a smaller,
// same-gate cousin of initMagneticCta() above — each link nudges toward the
// cursor and springs back with a short, bounce-free tween on leave. Transform
// only, so it never shifts layout. Hover-capable + fine pointer only.
function initMagneticNav(): void {
  if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    return;
  }
  const links = document.querySelectorAll<HTMLElement>("[data-magnetic-nav]");
  if (links.length === 0) {
    return;
  }

  const MAX_OFFSET_PX = 3;
  links.forEach((link) => {
    const moveX = gsap.quickTo(link, "x", { duration: DURATION_BASE, ease: "power2.out" });
    const moveY = gsap.quickTo(link, "y", { duration: DURATION_BASE, ease: "power2.out" });

    link.addEventListener("pointermove", (event) => {
      const rect = link.getBoundingClientRect();
      const relativeX = event.clientX - (rect.left + rect.width / 2);
      const relativeY = event.clientY - (rect.top + rect.height / 2);
      moveX(gsap.utils.clamp(-MAX_OFFSET_PX, MAX_OFFSET_PX, relativeX * 0.3));
      moveY(gsap.utils.clamp(-MAX_OFFSET_PX, MAX_OFFSET_PX, relativeY * 0.3));
    });

    link.addEventListener("pointerleave", () => {
      gsap.to(link, { x: 0, y: 0, duration: DURATION_FAST, ease: EASE_REVEAL });
    });
  });
}

// Pointer-reactive hero glow (Hero.astro → [data-hero-visual], Hero.module.scss
// → .visual-glow): eases the existing Perception Glow bloom toward the
// pointer within the hero visual, via the --glow-x/--glow-y custom
// properties (CSS default: the original static 50%/40% position). Same 18%
// peak alpha and radius as before — a following light, not a new effect.
// Hover-capable + fine pointer only; touch and no-pointer visitors keep the
// exact original static glow.
function initHeroPointerGlow(): void {
  if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    return;
  }
  const visual = document.querySelector<HTMLElement>("[data-hero-visual]");
  const glow = visual?.querySelector<HTMLElement>('[data-hero-layer="glow"]');
  if (!visual || !glow) {
    return;
  }

  const position = { x: 50, y: 40 };
  const applyPosition = (): void => {
    glow.style.setProperty("--glow-x", `${position.x}%`);
    glow.style.setProperty("--glow-y", `${position.y}%`);
  };
  const moveX = gsap.quickTo(position, "x", {
    duration: DURATION_SLOW,
    ease: "power2.out",
    onUpdate: applyPosition,
  });
  const moveY = gsap.quickTo(position, "y", { duration: DURATION_SLOW, ease: "power2.out" });

  visual.addEventListener("pointermove", (event) => {
    const rect = visual.getBoundingClientRect();
    moveX(gsap.utils.clamp(0, 100, ((event.clientX - rect.left) / rect.width) * 100));
    moveY(gsap.utils.clamp(0, 100, ((event.clientY - rect.top) / rect.height) * 100));
  });

  visual.addEventListener("pointerleave", () => {
    moveX(50);
    moveY(40);
  });
}
