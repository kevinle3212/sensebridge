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
type StopFn = (message?: string) => void;

export {};

(() => {
  const status = document.getElementById("read-aloud-status");
  const main = document.getElementById("main");
  if (!status || !main) {
    return;
  }

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

  function setupDeviceVoice(mainElement: HTMLElement): void {
    const IDLE_LABEL = "Listen (device voice)";
    const STOP_LABEL = "Stop reading";

    const toggleButton = document.getElementById("read-aloud-toggle");
    const label = toggleButton?.querySelector(".read-aloud__label");
    if (!(toggleButton instanceof HTMLButtonElement) || !(label instanceof HTMLElement)) {
      return;
    }
    if (!("speechSynthesis" in window) || typeof SpeechSynthesisUtterance === "undefined") {
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

    const start = (): void => {
      const text = mainElement.textContent.replace(/\s+/g, " ").trim();
      if (!text) {
        return;
      }

      setActive(stop);

      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = document.documentElement.lang || "en-US";
      utterance.onend = () => {
        setIdle();
        clearActive(stop);
        announce("Finished reading.");
      };
      utterance.onerror = () => {
        setIdle();
        clearActive(stop);
        announce("Reading stopped.");
      };

      window.speechSynthesis.cancel();
      window.speechSynthesis.speak(utterance);
      label.textContent = STOP_LABEL;
      toggleButton.setAttribute("aria-pressed", "true");
      announce("Reading page…");
    };

    setIdle();
    toggleButton.hidden = false;

    toggleButton.addEventListener("click", () => {
      if (window.speechSynthesis.speaking) {
        stop("Stopped.");
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
    const IDLE_LABEL = "Listen (natural voice)";
    const STOP_LABEL = "Stop reading";

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
        announce("Couldn't play the natural-voice narration.");
      });
      label.textContent = STOP_LABEL;
      toggleButton.setAttribute("aria-pressed", "true");
      announce("Reading page in a natural voice…");
    };

    audio.addEventListener("ended", () => {
      setIdle();
      clearActive(stop);
      announce("Finished reading.");
    });

    // /audio/main.mp3 only exists once scripts/generate-audio.js has been
    // run and its output committed — until then this fires and the control
    // never appears, leaving the device-voice option as the only one shown.
    audio.addEventListener(
      "error",
      () => {
        toggleButton.hidden = true;
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
        stop("Stopped.");
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
