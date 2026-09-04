// Pauses the site's looping decorative CSS animations while their section is
// scrolled out of view, so a long-lived page or an idle background tab stops
// burning GPU/compositor cycles on motion nobody can see. The 3D scenes already
// pause offscreen (scenes/core.ts's rAF loop gates on `inView`); this brings the
// pure-CSS loops to parity — the hero's Perception-Glow sweep and LiDAR rings
// (Hero.module.scss) and the Signal Bridge cogs (SignalBridge.module.scss),
// which otherwise run their `infinite` @keyframes forever.
//
// Loaded from BaseLayout.astro after `load`, at idle, behind the same
// reduced-motion gate as motion.ts / scenes: under `reduce` these animations
// never run at all (they live inside @include motion-safe), so there is nothing
// to pause and this module returns having observed nothing.
//
// Mechanism is the native Web Animations API, no CSS or markup coupling:
// Element.getAnimations({ subtree: true }) returns the CSS animations running
// under a container, and each exposes play()/pause(). GSAP tweens run on their
// own JS ticker rather than the WAAPI, so scroll/reveal motion is untouched.
export {};

// Every container that holds a looping decorative animation:
// [data-scene="hero"] wraps .device-sweep + .field-ring; [data-bridge-visual]
// wraps the idling cogs.
const CONTAINERS = "[data-scene], [data-bridge-visual]";

const observer = new IntersectionObserver((entries) => {
  for (const entry of entries) {
    const container = entry.target as HTMLElement;
    for (const animation of container.getAnimations({ subtree: true })) {
      if (entry.isIntersecting) {
        animation.play();
      } else {
        animation.pause();
      }
    }
  }
});

document.querySelectorAll<HTMLElement>(CONTAINERS).forEach((container) => {
  observer.observe(container);
});
