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

// Mirror --duration-slow / --duration-base from
// src/styles/abstracts/_motion.scss (GSAP needs numeric seconds; the CSS
// custom properties are for CSS transitions, not this file).
const DURATION_SLOW = 0.4;
const DURATION_BASE = 0.24;
// Mirrors --ease-out-expo ("reveals" per _motion.scss). GSAP's built-in
// "expo.out" is the standard named curve for that easing family.
const EASE_REVEAL = "expo.out";

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
  initSectionReveals();

  return () => {
    gsap.ticker.remove(driveLenis);
    lenis.destroy();
  };
});

function initHeroReveal(): void {
  const words = document.querySelectorAll<HTMLElement>("[data-hero-word]");
  const rest = document.querySelectorAll<HTMLElement>("[data-hero-reveal]");
  if (words.length === 0 && rest.length === 0) {
    return;
  }

  gsap.set(words, { opacity: 0, y: "0.6em" });
  gsap.set(rest, { opacity: 0, y: 16 });

  gsap
    .timeline({ defaults: { ease: EASE_REVEAL, duration: DURATION_SLOW } })
    .to(words, { opacity: 1, y: 0, stagger: 0.04 })
    .to(rest, { opacity: 1, y: 0, stagger: 0.08 }, "-=0.2");
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

function initSectionReveals(): void {
  document.querySelectorAll<HTMLElement>("[data-reveal]").forEach((section) => {
    gsap.set(section, { opacity: 0, y: 24 });
    gsap.to(section, {
      opacity: 1,
      y: 0,
      duration: DURATION_SLOW,
      ease: EASE_REVEAL,
      scrollTrigger: { trigger: section, start: "top 85%" },
    });
  });

  const items = Array.from(document.querySelectorAll<HTMLElement>("[data-reveal-item]"));
  const firstItem = items[0];
  if (firstItem) {
    gsap.set(items, { opacity: 0, y: 24 });
    gsap.to(items, {
      opacity: 1,
      y: 0,
      duration: DURATION_BASE,
      ease: EASE_REVEAL,
      stagger: 0.08,
      scrollTrigger: { trigger: firstItem, start: "top 85%" },
    });
  }
}
