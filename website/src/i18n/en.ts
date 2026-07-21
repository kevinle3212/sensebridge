import type { ThemeMode, Translations } from "./types";

const modeName: Record<ThemeMode, string> = { system: "system", light: "light", dark: "dark" };

export const en: Translations = {
  meta: {
    title: "SenseBridge — open-source, on-device, private accessibility",
    description:
      "SenseBridge is a free, open-source iPhone app that translates a blind or low-vision person's surroundings into clear spoken information, processed entirely on-device.",
  },
  layout: {
    skipLink: "Skip to main content",
  },
  header: {
    nav: {
      features: "Features",
      privacy: "Privacy",
      accessibility: "Accessibility",
      github: "GitHub",
    },
    themeToggle: {
      modeName,
      // `current`/`next` are the closed `ThemeMode` union, not arbitrary input.
      ariaLabel: (current, next) =>
        // eslint-disable-next-line security/detect-object-injection
        `Theme: ${modeName[current]}. Activate for ${modeName[next]} theme.`,
    },
    languageSwitcher: {
      label: "Language",
    },
  },
  hero: {
    heading: "Sense more. Share nothing.",
    lede: "SenseBridge is a free, open-source iPhone app that translates a blind or low-vision person's surroundings into clear spoken information — processed entirely on the device, so the camera and your surroundings never leave your phone.",
    status:
      "SenseBridge is in open development and not yet available to download. You can follow the build on GitHub today.",
    visuallyHiddenDescription:
      "If you are hearing this page rather than seeing it: the artwork here shows a signal traveling from a phone's camera, across a stylized bridge, and arriving as a spoken sentence — the same journey this page describes.",
    cta: "Follow progress on GitHub",
  },
  features: {
    heading: "What it does today",
    intro: "Five capabilities, all running entirely on the phone.",
    items: [
      "Reads printed text and documents aloud.",
      "Identifies common objects and surfaces.",
      "Describes a scene in a natural sentence.",
      "Gives cautious obstacle awareness using LiDAR — never navigation.",
      "Announces important sound events nearby.",
    ],
  },
  privacy: {
    heading: "Private by architecture, not by policy",
    body: "There is no backend, no account system, and no telemetry by default. Perception and reasoning run on-device; nothing about your surroundings leaves your phone without your explicit, revocable consent.",
    supporting: "A privacy policy can change. An architecture with no server cannot.",
  },
  accessibility: {
    heading: "Built the way it asks to be judged",
    body: "This site is built screen-reader-first, to the same standard the app promises: semantic structure, every control labeled, full keyboard support, WCAG 2.2 AA. If you use VoiceOver or NVDA, this page should already feel like home.",
    leadIn: "Prefer to listen? This page can read itself aloud.",
  },
  readAloud: {
    deviceIdleLabel: "Listen (device voice)",
    naturalIdleLabel: "Listen (natural voice)",
    stopLabel: "Stop reading",
    readingPage: "Reading page…",
    finishedReading: "Finished reading.",
    readingStopped: "Reading stopped.",
    stopped: "Stopped.",
    readingPageNatural: "Reading page in a natural voice…",
    naturalPlaybackError: "Couldn't play the natural-voice narration.",
  },
  bridge: {
    heading: "Built like its name",
    body: "SenseBridge exists to connect two things: a camera's raw signal, and the plain sentence a person is trying to hear. Everything between them — perception, reasoning, rendering — is the span of that bridge, assembled entirely on your phone.",
    supporting:
      "No cloud crossing. No account gate. Just the shortest path from sensing to understanding.",
  },
  phone: {
    heading: "The whole system is the phone in your pocket",
    lede: "No extra hardware, no cloud. SenseBridge is being built to run entirely on the iPhone's own sensors and silicon — here is how each part carries the signal.",
    diagramDescription:
      "Diagram: an iPhone drawn as a wireframe pulls apart into three layers. The camera and LiDAR scanner at the back capture the scene. The Neural Engine in the middle runs perception and reasoning models on-device. The speaker and Taptic Engine at the front turn understanding into speech and gentle haptics.",
    annotations: [
      {
        label: "01 · SENSING",
        title: "Camera + LiDAR",
        body: "Light and depth enter here. The camera and LiDAR scanner sample the scene's shape so the app has something truthful to describe. In the architecture this is the SensingSource seam — the only door the world comes in through.",
      },
      {
        label: "02 · REASONING",
        title: "Neural Engine",
        body: "On-device models turn pixels and depth into hedged, plain-language description. Perception and reasoning run entirely on the phone's own silicon — nothing is uploaded, nothing leaves your hand.",
      },
      {
        label: "03 · RENDERING",
        title: "Speaker + Taptic Engine",
        body: "What the phone understands comes back as speech and gentle haptics — the RenderTarget seam. Always phrased as awareness, never as a promise of safety.",
      },
    ],
  },
  future: {
    kicker: "A future direction — not a product",
    heading: "Where the bridge could go next",
    lede: "SenseBridge is being built for the phone first. But the same on-device pipeline — sense, reason, render — could one day ride on lighter hardware, closer to the senses it serves.",
    body: "Wearables like camera glasses could let the same hedged, private descriptions arrive hands-free. Nothing about that future is promised; the protocol seams are simply being designed so it stays possible.",
    illustrationDescription:
      "Illustration: a pair of glasses drawn as a translucent wireframe rotates slowly. Every few seconds, a small point of blue light travels the frame — down one temple, around its lens, across the bridge, around the other lens, and down the far temple — warming to amber as it arrives.",
  },
  followProgress: {
    heading: "Developed in the open",
    body: "Everything substantive you just read is verifiable: the code, the architecture decisions, and the distance still to go are all public. If SenseBridge earned your interest, the way to act on it today is to watch the build happen.",
    link: "Watch the build on GitHub",
  },
  footer: {
    tagline: "SenseBridge is free and open source. No subscription, ever.",
    githubLink: "SenseBridge on GitHub",
    notAvailable:
      "Not yet available on the App Store — SenseBridge is pre-launch and in open development.",
  },
  disclaimer: {
    ariaLabel: "Safety disclaimer",
    text: "SenseBridge raises awareness of your surroundings. It is not a mobility or navigation safety device, and its descriptions can be wrong — always use it alongside your own judgment, a cane, or a guide dog.",
  },
};
