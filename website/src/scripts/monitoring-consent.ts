/**
 * Consent state for browser error monitoring, and the switch that acts on it.
 *
 * Deliberately holds no reference to Sentry. Everything that touches the SDK
 * lives in `./monitoring`, which this module reaches only through a dynamic
 * `import()` — so the SDK becomes a separate chunk that a visitor who has not
 * opted in never downloads, parses, or runs. That is what makes "off by
 * default" true at the network layer rather than only at the config layer, on a
 * site whose whole posture is zero-JS-by-default (see scripts/check-zero-js.js).
 *
 * Opt-in, not opt-out, and no banner. Nothing is stored and nothing is sent
 * until the visitor uses the control on /privacy, which means there is no
 * consent to ask for on arrival — the strictest reading of GDPR/ePrivacy and
 * the least intrusive design at the same time. See docs/PRIVACY.md.
 */

/** Whether the visitor has answered, and how. Absent storage means "unset". */
export type MonitoringConsent = "granted" | "denied" | "unset";

/**
 * `localStorage` key holding the visitor's answer.
 *
 * Namespaced because `localStorage` is shared per-origin. Versionless on
 * purpose: if what is collected ever changes, the honest move is a new key so
 * previously granted consent does not silently carry over to a wider scope.
 */
export const MONITORING_CONSENT_KEY = "sensebridge.monitoring-consent";

/**
 * Event dispatched on `window` whenever the answer changes, carrying the new
 * value. Lets every rendered copy of the consent control stay in step without
 * any of them knowing about the others.
 */
export const MONITORING_CONSENT_EVENT = "sensebridge:monitoring-consent";

/**
 * Whether `./monitoring` has been imported in this page's lifetime.
 *
 * Load-bearing, not an optimisation: without it, switching consent *off* would
 * import the SDK purely to shut down something that was never started.
 */
let monitoringLoaded = false;

/**
 * Whether the browser is sending a Global Privacy Control signal.
 *
 * GPC is a standing, machine-readable opt-out. Strictly, CPRA only obliges a
 * site to honour it for sale or sharing, and this site does neither — but a
 * visitor who has configured their browser to say "do not collect" has
 * already answered the question this page asks, and asking again would be a
 * dark pattern. Treated here as a hard override rather than a default.
 */
export function isGlobalPrivacyControlEnabled(): boolean {
  return (
    (navigator as Navigator & { globalPrivacyControl?: boolean }).globalPrivacyControl === true
  );
}

/**
 * The visitor's effective answer, defaulting to `"unset"` — which is not
 * consent. A GPC signal outranks anything in storage, including a previously
 * granted consent, so turning GPC on retroactively switches monitoring off.
 */
export function readMonitoringConsent(): MonitoringConsent {
  if (isGlobalPrivacyControlEnabled()) {
    return "denied";
  }
  try {
    const stored = window.localStorage.getItem(MONITORING_CONSENT_KEY);
    return stored === "granted" || stored === "denied" ? stored : "unset";
  } catch {
    // Safari in private mode, and any browser with site data blocked, throws on
    // `localStorage` access. Unreadable storage is treated as no consent, which
    // is the safe direction to fail in.
    return "unset";
  }
}

/**
 * Records the visitor's answer, acts on it immediately, and tells every
 * rendered control about it.
 *
 * A stored `"denied"` is not tracking: it is the only way to remember that the
 * question was answered, and it is what the visitor asked for.
 */
export function setMonitoringConsent(consent: "granted" | "denied"): void {
  try {
    window.localStorage.setItem(MONITORING_CONSENT_KEY, consent);
  } catch {
    // Storage refused. The choice still applies for this page — it just will
    // not survive a reload, which is the browser's decision, not ours.
  }
  void applyMonitoringConsent();
  window.dispatchEvent(
    new CustomEvent<MonitoringConsent>(MONITORING_CONSENT_EVENT, { detail: consent }),
  );
}

/**
 * Starts or stops monitoring to match the stored answer.
 *
 * Returns without importing anything in the common case — no consent, nothing
 * loaded — so a visitor who never opts in pays nothing for this module beyond
 * one `localStorage` read.
 */
export async function applyMonitoringConsent(): Promise<void> {
  const granted = readMonitoringConsent() === "granted";
  if (!granted && !monitoringLoaded) {
    return;
  }
  const monitoring = await import("./monitoring");
  monitoringLoaded = true;
  if (granted) {
    monitoring.startMonitoring();
  } else {
    monitoring.stopMonitoring();
  }
}
