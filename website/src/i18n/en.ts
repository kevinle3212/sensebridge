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
    fullNoticeLink: "Read the full privacy and data notice",
  },
  monitoring: {
    controlLabel: "Error monitoring",
    stateOn: "On — reports are sent when a page breaks",
    stateOff: "Off — nothing is sent",
    noScript:
      "This switch needs JavaScript. With JavaScript off, error monitoring cannot run either, so nothing is being collected.",
    globalPrivacyControl:
      "Your browser is sending a Global Privacy Control signal, so error monitoring stays off and this switch is not shown. Nothing is being collected.",
  },
  privacyPage: {
    title: "Privacy and data — SenseBridge",
    description:
      "What this site collects, what it does not, and how to turn error monitoring on or off. No cookies, no analytics, no advertising.",
    heading: "Privacy and data",
    lede: "This site collects nothing about you by default. Here is exactly what that means, what changes if you choose otherwise, and how to change your mind.",
    updated: "Last updated",
    authoritative:
      "This notice is published in several languages. Where they differ, the English version governs.",
    choiceHeading: "Your choice",
    choiceBody:
      "Error monitoring is off until you turn it on. On, it sends a report when a page on this site breaks — what went wrong and where in our code, never who you are. Switching it back off stops it immediately.",
    choiceUnconfigured:
      "This deployment has no error monitoring configured, so there is nothing to turn on and nothing is being collected.",
    sections: [
      {
        heading: "The short version",
        body: [
          "No cookies. No analytics. No advertising. No tracking pixels. No profiling. Nothing is sold, and nothing is shared for anyone else's marketing.",
          "The only thing this site can send about your visit is a report that a page broke, and only if you switch it on above.",
        ],
      },
      {
        heading: "What is stored on your device",
        body: [
          "Only preferences you set yourself. None of these is an identifier, none is readable by any other site, and none is ever transmitted anywhere:",
        ],
        bullets: [
          "Whether you turned error monitoring on or off, once you have used the switch above.",
          "Your light or dark theme, if you change it from the system default.",
          "A developer debug flag, only if you set one by hand.",
        ],
      },
      {
        heading: "What the web server sees",
        body: [
          "Like every web server on the internet, the host serving these pages processes your IP address, the page you asked for, your browser's user-agent string, and the time — because a page cannot be delivered without them. This site is hosted by Vercel.",
          "That data is used to serve the page and to defend the site against abuse. It is not combined with anything else, not used to build a profile of you, and we keep no copy of it.",
        ],
      },
      {
        heading: "If you turn error monitoring on",
        body: [
          "Only then does this site load Sentry, an error-reporting service. Until you say yes, that code is never downloaded — not loaded and disabled, not present and idle. Absent.",
        ],
        bullets: [
          "Sent when a page breaks: the error message, the place in our code it came from, the page path without its query string, your browser and operating system version, and your screen size.",
          "Never sent: your name, your email address, your IP address, your cookies, your location, the contents of anything you typed, or any recording of your screen or of what you clicked.",
          "Session Replay, performance tracing, breadcrumbs, and the feedback widget are switched off in code, not merely left unused.",
        ],
      },
      {
        heading: "Why, and on what legal basis",
        body: [
          "For visitors in the United Kingdom, the EEA, and Switzerland, the UK GDPR and the GDPR require a named legal basis for each purpose:",
        ],
        bullets: [
          "Error monitoring — your consent, under Article 6(1)(a). You can withdraw it at any time with the switch above, which is exactly as easy as giving it. Withdrawing does not undo processing that already happened.",
          "Serving these pages and keeping the site available — our legitimate interests in running a website that works and is not abused, under Article 6(1)(f).",
          "Remembering your preference on your device — strictly necessary to provide something you asked for, so the storage itself needs no separate consent under Article 5(3) of the ePrivacy Directive.",
        ],
      },
      {
        heading: "Who else is involved",
        body: [
          "Two companies, both in the United States, both acting only on our instructions under a data processing agreement:",
        ],
        bullets: [
          "Vercel Inc. — hosting and delivery of these pages.",
          "Functional Software, Inc., trading as Sentry — error reports, and only if you turned them on.",
        ],
      },
      {
        heading: "Leaving the UK and the EEA",
        body: [
          "Both providers are in the United States, so any personal data they process leaves the UK and the EEA. Those transfers rely on the European Commission's Standard Contractual Clauses and the UK Addendum to them.",
          "No one else receives anything. We do not sell personal information, and we do not share it for cross-context behavioural advertising as those terms are defined in California's CCPA and CPRA.",
        ],
      },
      {
        heading: "How long it is kept",
        bullets: [
          "Error reports: 90 days in Sentry, then deleted automatically.",
          "The preference on your device: until you change it or clear this site's data in your browser.",
          "Web server logs: kept by the host for a short operational period, and never copied anywhere by us.",
        ],
        body: [],
      },
      {
        heading: "Your rights",
        body: [
          "If you are in the UK, the EEA, or Switzerland, you can ask what we hold about you, have it corrected or deleted, restrict or object to how it is used, receive it in a portable form, and withdraw consent at any time. You can also complain to your national data protection authority — in the UK, the Information Commissioner's Office.",
          "If you are in California, Colorado, Connecticut, Virginia, Texas, or another US state with a consumer privacy law, you have the equivalent rights to know, delete, correct, and opt out. We honour the Global Privacy Control signal: if your browser sends one, error monitoring stays off no matter what the switch says.",
          "In practice there is usually nothing to hand over. Error reports carry no identifier we could look you up by, which is the point of collecting them that way. Write to the address below and you will get an answer within 30 days — including, honestly, that we hold nothing.",
        ],
      },
      {
        heading: "Children",
        body: [
          "This site is not directed to children, and it collects nothing from anyone that would identify them, at any age.",
        ],
      },
      {
        heading: "The SenseBridge app",
        body: [
          "The app is a separate thing, and it is not released yet. It processes camera, microphone, and depth data entirely on your device and sends none of it anywhere.",
          "It has its own crash reporting, off by default, behind the same kind of switch under Settings, then Diagnostics. On, it sends a report if the app crashes or freezes: where in the code it happened, your iPhone model, and the iOS and app versions. Never an image, never what the camera read, never audio, never your location.",
        ],
      },
      {
        heading: "Changes to this notice",
        body: [
          "If what is collected ever changes, this page changes first. Consent given under a narrower description is asked for again rather than quietly carried over to a wider one.",
        ],
      },
      {
        heading: "Contact",
        body: [
          "Kevin K. Le, the project's maintainer, is the data controller. Write to kevinle3212@gmail.com about anything on this page.",
        ],
      },
    ],
  },
  accessibility: {
    heading: "Built the way it asks to be judged",
    body: "This site is built screen-reader-first, to the same standard the app promises: semantic structure, every control labeled, full keyboard support, WCAG 2.2 AA. If you use VoiceOver or NVDA, this page should already feel like home.",
    leadIn: "Prefer to listen? This page can read itself aloud.",
  },
  accessibilityPage: {
    title: "Accessibility statement — SenseBridge",
    description:
      "What is verified, what is not, and how to report a barrier. Written to be checkable rather than reassuring.",
    heading: "Accessibility statement",
    lede: "SenseBridge is an accessibility product. That raises the standard this site should be held to rather than lowering it — so this statement is written to be checked, not believed. Where something is verified, it says what verified it. Where it is not, it says so.",
    updated: "Last reviewed",
    authoritative:
      "This statement is published in several languages. Where they differ, the English version governs.",
    sections: [
      {
        heading: "The standards we build to",
        body: [
          "WCAG 2.2 Level AA is the binding baseline for this site and for the app. Every automated check below enforces it.",
          "EN 301 549 v3.2.1 — the European harmonised standard, and the one the European Accessibility Act is assessed against — incorporates that same Level AA baseline for web content.",
          "Level AAA is an aspiration, met in specific places and not claimed as conformance. The W3C itself advises that Level AAA is not achievable for entire sites as a general policy, and we agree.",
        ],
      },
      {
        heading: "Conformance status",
        body: [
          "This site is partially conformant with WCAG 2.2 Level AA and EN 301 549 v3.2.1, in the specific sense those templates use the phrase: automated testing finds no violations, and no independent party has performed a manual audit. The gap is described under “What has not been done”, because that gap is the useful part of a statement like this one.",
        ],
      },
      {
        heading: "What is checked on every change",
        body: [
          "None of these is a one-off report. Each one runs before a change can ship, and a failure stops it:",
        ],
        bullets: [
          "Every published page is tested against the WCAG 2.2 Level AA ruleset with two independent engines — HTML CodeSniffer and axe-core — in a browser forced into reduced-motion. A single error fails the build.",
          "Every published page is also tested against the Level AAA ruleset. That pass reports rather than blocks, for the reason given below.",
          "Every page is a complete, readable document with JavaScript switched off. Motion is opt-in, and instantiates nothing at all when your system asks for reduced motion.",
          "The production Content-Security-Policy is exercised against the built site, so a policy that silently drops a stylesheet cannot ship and leave these pages unstyled and unreadable.",
          "The narrated audio is checked against the page text, so a wording change cannot quietly leave stale narration behind.",
        ],
      },
      {
        heading: "Where we go beyond Level AA",
        body: [
          "Named individually rather than claimed as a level, because a Level AAA criterion met on one page is not Level AAA conformance:",
        ],
        bullets: [
          "1.4.6 Contrast (Enhanced) — every colour that carries text on this site meets the 7:1 Level AAA ratio, not the 4.5:1 Level AA floor, and meets it against the darkest background it is ever placed on rather than only against the page background.",
          "2.2.3 No Timing — nothing here is time-limited.",
          "2.3.2 Three Flashes — nothing flashes at all.",
          "2.4.9 Link Purpose (Link Only) — links are written to make sense read out of context, which is how a screen-reader rotor presents them.",
          "3.3.5 Help — the route to report a barrier is in the footer of every page, not buried in a support section.",
        ],
      },
      {
        heading: "Why we do not claim Level AAA",
        body: [
          "Claiming it site-wide would be exactly the kind of overclaim this statement exists to avoid. Specifically: a signed version of the narrated audio does not exist (1.2.6), and the reading-level and pronunciation criteria (3.1.3 to 3.1.6) impose obligations on translated content that a three-language site maintained by one person cannot honestly guarantee on every change.",
          "Where a Level AAA criterion is cheap and durable, we take it. Where meeting it would require a promise we cannot keep on every change, we say so here instead of claiming it.",
        ],
      },
      {
        heading: "What has not been done",
        body: [
          "Stated plainly, because an accessibility statement that lists only its successes is marketing:",
        ],
        bullets: [
          "No independent third-party accessibility audit has been carried out, on this site or on the app.",
          "No formal validation with blind and low-vision testers has been completed. Automated checks cannot tell you whether a page makes sense to someone navigating it by ear; only those users can. This is the project's largest open accessibility risk, and it is tracked as one.",
          "Automated testing has limits. Tools of this kind catch a minority of real barriers — commonly cited as around a third. A page can pass every automated rule and still be confusing, mislabeled, or unusable in practice.",
          "No VPAT or Accessibility Conformance Report has been produced.",
        ],
      },
      {
        heading: "Known limitations",
        bullets: [
          "The narrated audio covers the main content of the home page, not navigation or the footer.",
          "The Spanish and Vietnamese pages are reviewed for accuracy of meaning, but have not been tested with a screen reader running in those languages.",
          "Where a browser or operating-system control appears, its accessibility is governed by whoever makes it, not by us.",
          "High-contrast and forced-colours rendering is implemented against the platform's own settings but has not been audited by an outside party.",
        ],
        body: [],
      },
      {
        heading: "The SenseBridge app",
        body: [
          "Conformance is not yet claimed for the app. It has not been publicly released, and this statement will not pretend a pre-launch build has been audited.",
          "Its internal gate is stricter than a percentage — zero unlabeled interactive elements on every screen, with a VoiceOver pass required on any changed interface before the change can merge — but a gate is a development discipline, not a conformance audit.",
        ],
      },
      {
        heading: "Tell us about a barrier",
        body: [
          "If any part of SenseBridge is not usable for you, that is a defect, and it is treated with the same priority as a crash — not as a feature request.",
          "Write to kevinle3212@gmail.com. Describe what you were trying to do, what assistive technology you were using and its version if you know it, and what happened instead. You do not need to know the technical cause, and you do not need to phrase it in accessibility terminology.",
          "We aim to acknowledge you within 5 working days, and to give a substantive answer — a fix, or a timeline for one — within 30 days. This is the feedback mechanism the European Accessibility Act and EN 301 549 require a statement to name, and it is read by the maintainer directly.",
        ],
      },
      {
        heading: "If we do not fix it",
        body: [
          "This project is pre-launch, free, and maintained by one person. There is no formal enforcement body engaged with it. If we do not resolve your report, you keep every escalation route the law where you live gives you — the market-surveillance authority designated by your EU Member State, the Equality Act route in the United Kingdom, a Department of Justice complaint under the ADA in the United States, the Accessibility Commissioner in Canada, or the Australian Human Rights Commission.",
          "Nothing in this statement, and nothing in our terms, limits any of those routes.",
        ],
      },
      {
        heading: "How this statement is kept honest",
        body: [
          "It is reviewed whenever a change touches an accessibility check, and at minimum once every twelve months. The full version, including the specific laws it is written against, is published in the project repository as legal/ACCESSIBILITY_STATEMENT.md. Neither document may claim a check the other does not.",
        ],
      },
    ],
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
    replay: "Replay the bridge animation",
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
    privacyLink: "Privacy and data",
    accessibilityLink: "Accessibility statement",
    notAvailable:
      "Not yet available on the App Store — SenseBridge is pre-launch and in open development.",
    voiceCredit: "Natural voice narration generated with elevenlabs.io.",
    monitoringCredit: "Error monitoring available via sentry.io, off until you opt in.",
    poweredBy: "Powered by",
    makerPhotoAlt: "Kevin K. Le, the current sole developer of the project",
  },
  disclaimer: {
    ariaLabel: "Safety disclaimer",
    text: "SenseBridge raises awareness of your surroundings. It is not a mobility or navigation safety device, and its descriptions can be wrong — always use it alongside your own judgment, a cane, or a guide dog.",
  },
  errorPages: {
    backHome: "Back to the homepage",
    notFound: {
      heading: "This page fell in a hole.",
      body: "Somewhere between here and there, this page wandered off and, well, ended up in a hole. It happens to the best of us — the rest of the site is still on solid ground.",
    },
    badRequest: {
      heading: "Something about that request wasn't quite right.",
      body: "The page didn't fall in a hole this time — the request itself took a wrong turn before it got here.",
    },
    serverError: {
      heading: "Something broke on our end. Sorry about that.",
      body: "Even a well-drawn cow has an off day. Nothing you did caused this — try again in a moment.",
    },
    statusLabel: "HTTP {code} · {phrase}",
    classes: {
      informational: {
        heading: "This one is the protocol thinking out loud.",
        body: "A 1xx status is an interim reply — the server saying it is still working on the real one. You will almost never see it in a browser, but it has a page here anyway.",
      },
      success: {
        heading: "Nothing went wrong here.",
        body: "A 2xx status means the request worked. The cow is falling for its own reasons — this page is just here so every code in the registry has one.",
      },
      redirect: {
        heading: "This one points somewhere else.",
        body: "A 3xx status means what you asked for lives at a different address. Normally your browser follows it without ever showing you this.",
      },
      client: {
        heading: "That request didn't quite land.",
        body: "A 4xx status means something about the request itself was off — the address, the method, or what came with it. The rest of the site is still on solid ground.",
      },
      server: {
        heading: "Something broke on our end.",
        body: "A 5xx status means the request was fine and the server was not. Nothing you did caused this — try again in a moment.",
      },
    },
  },
};
