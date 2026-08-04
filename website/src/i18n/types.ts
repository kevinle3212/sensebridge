// Locale codes served by this site — must match astro.config.mjs's
// `i18n.locales`.
export type Locale = "en" | "es" | "vi";

export type ThemeMode = "system" | "light" | "dark";

/** Heading and body copy for one HTTP status page. */
export interface ErrorCopy {
  heading: string;
  body: string;
}

/**
 * One headed block of a published notice — the privacy notice at `/privacy` or
 * the accessibility statement at `/accessibility`, which are the same shape.
 * `bullets` is optional because some sections are prose only; a list is used
 * where the content is genuinely a set of parallel items, not to break up a
 * paragraph — a screen-reader user hears "list, 6 items" before every one.
 */
export interface NoticeSection {
  heading: string;
  body: readonly string[];
  bullets?: readonly string[];
}

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
    /** Link from the home page's privacy section through to `/privacy`. */
    fullNoticeLink: string;
  };
  /** Strings for the error-monitoring consent switch (MonitoringConsent.astro). */
  monitoring: {
    controlLabel: string;
    stateOn: string;
    stateOff: string;
    /** Shown instead of the switch when scripting is unavailable. */
    noScript: string;
    /**
     * Shown instead of the switch when the browser sends a Global Privacy
     * Control signal, which this site treats as a standing opt-out.
     */
    globalPrivacyControl: string;
  };
  /** The full privacy and data-use notice at `/privacy`. */
  privacyPage: {
    title: string;
    description: string;
    heading: string;
    lede: string;
    /** Rendered as "Last updated <date>"; the date is supplied by the page. */
    updated: string;
    /**
     * Names English as the authoritative text. Present in every locale
     * including `en`, where it is not rendered — a translated legal notice
     * that does not say which version governs is the ambiguity this avoids.
     */
    authoritative: string;
    choiceHeading: string;
    choiceBody: string;
    /**
     * Replaces the switch when this deployment has no monitoring configured at
     * all, so the page never implies a choice that does not exist.
     */
    choiceUnconfigured: string;
    sections: readonly NoticeSection[];
  };
  accessibility: {
    heading: string;
    body: string;
    leadIn: string;
  };
  /**
   * The published accessibility statement at `/accessibility`. The European
   * Accessibility Act and EN 301 549 both require the statement to be
   * *published on the service itself*, not only kept in the repository, which
   * is why this exists as a page rather than as a link to
   * `legal/ACCESSIBILITY_STATEMENT.md`.
   */
  accessibilityPage: {
    title: string;
    description: string;
    heading: string;
    lede: string;
    /** Rendered as "Last updated <date>"; the date is supplied by the page. */
    updated: string;
    /** Names English as the authoritative text, as `privacyPage` does. */
    authoritative: string;
    sections: readonly NoticeSection[];
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
    /** Label for the control that replays the bridge construction animation. */
    replay: string;
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
    privacyLink: string;
    /** Link from every page's footer through to `/accessibility`. */
    accessibilityLink: string;
    notAvailable: string;
    voiceCredit: string;
    /** Shown only when `PUBLIC_SENTRY_DSN` is set at build time. */
    monitoringCredit: string;
    poweredBy: string;
    makerPhotoAlt: string;
  };
  disclaimer: {
    ariaLabel: string;
    text: string;
  };
  errorPages: {
    backHome: string;
    /**
     * Rendered above the heading. `{code}` and `{phrase}` are substituted with
     * the status code and its IANA reason phrase. Deliberately says "HTTP"
     * rather than "Error": the same page template serves 1xx/2xx/3xx codes,
     * which are not errors.
     */
    statusLabel: string;
    notFound: ErrorCopy;
    badRequest: ErrorCopy;
    serverError: ErrorCopy;
    /**
     * Fallback copy for every registered code without hand-written copy, keyed
     * by status class. `{phrase}` is substituted with the reason phrase.
     */
    classes: {
      informational: ErrorCopy;
      success: ErrorCopy;
      redirect: ErrorCopy;
      client: ErrorCopy;
      server: ErrorCopy;
    };
  };
}
