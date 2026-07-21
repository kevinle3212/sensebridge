// Locale codes served by this site — must match astro.config.mjs's
// `i18n.locales`.
export type Locale = "en" | "es" | "vi";

export type ThemeMode = "system" | "light" | "dark";

// Every string currently hardcoded across the site's components, grouped by
// the component that owns it. Each locale module (en.ts/es.ts/vi.ts) must
// implement this in full — a missing key is a compile error, not a silent
// runtime fallback.
export interface Translations {
  meta: {
    title: string;
    description: string;
  };
  layout: {
    skipLink: string;
  };
  header: {
    nav: {
      features: string;
      privacy: string;
      accessibility: string;
      github: string;
    };
    themeToggle: {
      modeName: Record<ThemeMode, string>;
      ariaLabel: (current: ThemeMode, next: ThemeMode) => string;
    };
    languageSwitcher: {
      label: string;
    };
  };
  hero: {
    heading: string;
    lede: string;
    status: string;
    visuallyHiddenDescription: string;
    cta: string;
  };
  features: {
    heading: string;
    intro: string;
    items: readonly [string, string, string, string, string];
  };
  privacy: {
    heading: string;
    body: string;
    supporting: string;
  };
  accessibility: {
    heading: string;
    body: string;
    leadIn: string;
  };
  readAloud: {
    deviceIdleLabel: string;
    naturalIdleLabel: string;
    stopLabel: string;
    readingPage: string;
    finishedReading: string;
    readingStopped: string;
    stopped: string;
    readingPageNatural: string;
    naturalPlaybackError: string;
  };
  bridge: {
    heading: string;
    body: string;
    supporting: string;
  };
  phone: {
    heading: string;
    lede: string;
    diagramDescription: string;
    annotations: readonly [
      { label: string; title: string; body: string },
      { label: string; title: string; body: string },
      { label: string; title: string; body: string },
    ];
  };
  future: {
    kicker: string;
    heading: string;
    lede: string;
    body: string;
    illustrationDescription: string;
  };
  followProgress: {
    heading: string;
    body: string;
    link: string;
  };
  footer: {
    tagline: string;
    githubLink: string;
    notAvailable: string;
  };
  disclaimer: {
    ariaLabel: string;
    text: string;
  };
}
