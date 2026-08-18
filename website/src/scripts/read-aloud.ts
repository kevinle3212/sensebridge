// Two "listen to this page" options, both progressive enhancement — TS port
// of the pre-Astro js/read-aloud.js, same contract:
//
// 1. Device voice — the browser's built-in Web Speech API. No network calls,
//    no API key, no backend. Always available if the browser supports it.
// 2. Natural voice — a pre-rendered ElevenLabs narration (/audio/main.mp3),
//    generated at build time by scripts/generate-audio.js and shipped as a
//    plain static file. The deployed site never holds the ElevenLabs API
//    key and never calls ElevenLabs at request time — this file just plays
//    static audio. If /audio/main.mp3 hasn't been generated yet, the
//    control detects that (via the <audio> element's `error` event) and
//    hides itself, so the feature degrades to option 1 with no broken
//    button.
//
// Both buttons stay `hidden` in the markup (see ReadAloud.astro) and are
// only revealed here, after confirming each is actually usable, so
// unsupported/unavailable options never show a dead control. Starting one
// stops the other.
import { debugLog } from "./debug";
import { m } from "../paraglide/messages.js";

/**
 * Cancels whichever reader is running. The optional message is announced in
 * the live region; omitting it stops silently, which is what an automatic stop
 * (tab hidden, page unload) wants.
 */
type StopFn = (message?: string) => void;

/** One chunk of the page: its heading, if it has one, and the text to speak. */
interface Segment {
  heading: string | null;
  text: string;
}

export {};

(() => {
  const status = document.getElementById("read-aloud-status");
  const main = document.getElementById("main");
  if (!status || !main) {
    return;
  }

  // Paraglide's `url` strategy resolves the active locale from the page's
  // own URL in the browser (see src/middleware.ts), so no explicit locale
  // lookup is needed here the way `useTranslations` used to require one.

  const announce = (message: string): void => {
    status.textContent = message;
  };

  let activeStop: StopFn | null = null;

  const setActive = (stop: StopFn): void => {
    if (activeStop && activeStop !== stop) {
      activeStop();
    }
    activeStop = stop;
  };

  const clearActive = (stop: StopFn): void => {
    if (activeStop === stop) {
      activeStop = null;
    }
  };

  setupDeviceVoice(main);
  setupNaturalVoice();

  /** Collapses whitespace the way a screen reader would hear it. */
  function normalize(text: string | null): string {
    return (text ?? "").replace(/\s+/g, " ").trim();
  }

  /**
   * Splits `main` into one segment per top-level `<section>`, keeping anything
   * before the first section as an unheaded preamble.
   *
   * Walks `children` rather than `querySelectorAll("section")` for two
   * reasons: it preserves document order between sections and the loose
   * content around them, and a nested section would otherwise be read twice —
   * once inside its parent's `textContent` and once on its own.
   *
   * Returns a single whole-page segment when the page has no sections at all,
   * so this can never read *less* of the page than the old monolithic
   * utterance did.
   */
  function segmentsOf(mainElement: HTMLElement): Segment[] {
    const segments: Segment[] = [];
    let preamble = "";

    for (const child of Array.from(mainElement.children)) {
      if (child.tagName === "SECTION") {
        if (preamble) {
          segments.push({ heading: null, text: preamble });
          preamble = "";
        }
        const heading = child.querySelector("h2, h1");
        segments.push({
          heading: heading ? normalize(heading.textContent) || null : null,
          text: normalize(child.textContent),
        });
      } else {
        preamble = normalize(`${preamble} ${normalize(child.textContent)}`);
      }
    }
    if (preamble) {
      segments.push({ heading: null, text: preamble });
    }

    const withText = segments.filter((segment) => segment.text);
    return withText.length > 0
      ? withText
      : [{ heading: null, text: normalize(mainElement.textContent) }];
  }

  function setupDeviceVoice(mainElement: HTMLElement): void {
    const IDLE_LABEL = m.read_aloud_device_idle_label();
    const STOP_LABEL = m.read_aloud_stop_label();

    const toggleButton = document.getElementById("read-aloud-toggle");
    const label = toggleButton?.querySelector(".read-aloud__label");
    if (!(toggleButton instanceof HTMLButtonElement) || !(label instanceof HTMLElement)) {
      return;
    }
    if (!("speechSynthesis" in window) || typeof SpeechSynthesisUtterance === "undefined") {
      debugLog("read-aloud", "device voice unavailable: no Web Speech API");
      return;
    }

    const setIdle = (): void => {
      label.textContent = IDLE_LABEL;
      toggleButton.setAttribute("aria-pressed", "false");
    };

    const stop: StopFn = (message) => {
      window.speechSynthesis.cancel();
      setIdle();
      clearActive(stop);
      if (message) {
        announce(message);
      }
    };

    // One utterance per section rather than one for the whole page. A single
    // monolithic utterance gives a listener no sense of where they are in the
    // document and nothing to orient by; announcing each section's own heading
    // as it starts turns the same audio into something navigable. It also
    // works around a long-standing engine limit — several browsers truncate or
    // stall on very long utterances — without that being the reason for it.
    //
    // Chained through `onend` rather than queued all at once: the queue would
    // survive a `cancel()` race on some engines, and chaining means the stage
    // announcement always lands with the audio it describes.
    const start = (): void => {
      const segments = segmentsOf(mainElement);
      if (segments.length === 0) {
        return;
      }

      setActive(stop);
      const language = document.documentElement.lang || "en-US";

      const speakFrom = (index: number): void => {
        // `.at()`, not `segments[index]`: indexing an array with a variable is
        // an object-injection sink to eslint-plugin-security, which this repo
        // runs at `error` for every rule.
        const segment = segments.at(index);
        if (!segment) {
          setIdle();
          clearActive(stop);
          announce(m.read_aloud_finished_reading());
          return;
        }

        // Polite, not assertive: the live region is `aria-live="polite"`, so
        // this queues behind whatever the user is already hearing instead of
        // interrupting the previous section's closing words.
        announce(
          segment.heading
            ? m.read_aloud_now_section({ section: segment.heading })
            : m.read_aloud_reading_page(),
        );

        const utterance = new SpeechSynthesisUtterance(segment.text);
        utterance.lang = language;
        utterance.onend = () => {
          // A `cancel()` from `stop()` also fires `onend` on some engines.
          // Without this guard the chain would march on through the remaining
          // sections after the user pressed stop.
          if (activeStop !== stop) {
            return;
          }
          speakFrom(index + 1);
        };
        utterance.onerror = () => {
          setIdle();
          clearActive(stop);
          announce(m.read_aloud_reading_stopped());
        };
        window.speechSynthesis.speak(utterance);
      };

      window.speechSynthesis.cancel();
      label.textContent = STOP_LABEL;
      toggleButton.setAttribute("aria-pressed", "true");
      speakFrom(0);
    };

    setIdle();
    toggleButton.hidden = false;

    toggleButton.addEventListener("click", () => {
      if (window.speechSynthesis.speaking) {
        stop(m.read_aloud_stopped());
      } else {
        start();
      }
    });

    const stopIfSpeaking = (): void => {
      if (window.speechSynthesis.speaking) {
        stop();
      }
    };
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        stopIfSpeaking();
      }
    });
    window.addEventListener("pagehide", stopIfSpeaking);
  }

  function setupNaturalVoice(): void {
    const IDLE_LABEL = m.read_aloud_natural_idle_label();
    const STOP_LABEL = m.read_aloud_stop_label();

    const toggleButton = document.getElementById("read-aloud-natural-toggle");
    const label = toggleButton?.querySelector(".read-aloud-natural__label");
    const audio = document.getElementById("read-aloud-natural-audio");
    if (
      !(toggleButton instanceof HTMLButtonElement) ||
      !(label instanceof HTMLElement) ||
      !(audio instanceof HTMLAudioElement)
    ) {
      return;
    }

    const setIdle = (): void => {
      label.textContent = IDLE_LABEL;
      toggleButton.setAttribute("aria-pressed", "false");
    };

    const stop: StopFn = (message) => {
      audio.pause();
      audio.currentTime = 0;
      setIdle();
      clearActive(stop);
      if (message) {
        announce(message);
      }
    };

    const start = (): void => {
      setActive(stop);
      void audio.play().catch(() => {
        setIdle();
        clearActive(stop);
        announce(m.read_aloud_natural_playback_error());
      });
      label.textContent = STOP_LABEL;
      toggleButton.setAttribute("aria-pressed", "true");
      announce(m.read_aloud_reading_page_natural());
    };

    // Progress broadcast, for anything that wants to follow the narration.
    //
    // A `CustomEvent` on `document` rather than a direct call into the motion
    // layer: this script is progressive enhancement that must keep working with
    // the motion layer absent (reduced motion, a JS error there, a page that
    // has no spine), and the motion layer must not have to know an audio
    // element exists. Either side can be missing and the other still runs.
    const broadcast = (playing: boolean): void => {
      const duration = audio.duration;
      const progress = Number.isFinite(duration) && duration > 0 ? audio.currentTime / duration : 0;
      document.dispatchEvent(
        new CustomEvent("sensebridge:narration", { detail: { progress, playing } }),
      );
    };
    audio.addEventListener("timeupdate", () => {
      broadcast(!audio.paused);
    });
    audio.addEventListener("play", () => {
      broadcast(true);
    });
    audio.addEventListener("pause", () => {
      broadcast(false);
    });

    audio.addEventListener("ended", () => {
      setIdle();
      clearActive(stop);
      broadcast(false);
      announce(m.read_aloud_finished_reading());
    });

    // /audio/main.mp3 only exists once scripts/generate-audio.js has been
    // run and its output committed — until then this fires and the control
    // never appears, leaving the device-voice option as the only one shown.
    audio.addEventListener(
      "error",
      () => {
        toggleButton.hidden = true;
        debugLog("read-aloud", "natural voice hidden: /audio/main.mp3 failed to load");
      },
      { once: true },
    );

    audio.addEventListener(
      "canplay",
      () => {
        setIdle();
        toggleButton.hidden = false;
      },
      { once: true },
    );

    toggleButton.addEventListener("click", () => {
      if (!audio.paused) {
        stop(m.read_aloud_stopped());
      } else {
        start();
      }
    });

    const stopIfPlaying = (): void => {
      if (!audio.paused) {
        stop();
      }
    };
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        stopIfPlaying();
      }
    });
    window.addEventListener("pagehide", stopIfPlaying);

    audio.preload = "metadata";
    audio.load();
  }
})();
