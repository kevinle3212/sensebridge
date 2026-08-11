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
 *
 * Persists to IndexedDB (via `./idb-store`), not `localStorage` — this value
 * is never needed before first paint, so the async read costs nothing
 * visible. See `docs/PRIVACY.md` and TODO.md's "Add localStorage migration to
 * databases" entry for why: on-device only, no hosted store.
 */

import { idbGet, idbSet } from "./idb-store";

/** Whether the visitor has answered, and how. Absent storage means "unset". */
export type MonitoringConsent = "granted" | "denied" | "unset";

/**
 * IndexedDB key holding the visitor's answer.
 *
 * Namespaced because the store is shared per-origin. Versionless on purpose:
 * if what is collected ever changes, the honest move is a new key so
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
export async function readMonitoringConsent(): Promise<MonitoringConsent> {
  if (isGlobalPrivacyControlEnabled()) {
    return "denied";
  }
  const stored = await idbGet(MONITORING_CONSENT_KEY);
  return stored === "granted" || stored === "denied" ? stored : "unset";
}

/**
 * Records the visitor's answer, acts on it immediately, and tells every
 * rendered control about it.
 *
 * A stored `"denied"` is not tracking: it is the only way to remember that the
 * question was answered, and it is what the visitor asked for.
 *
 * Stays a synchronous `void` function like its `localStorage` predecessor —
 * callers (e.g. the click handler in `MonitoringConsent.astro`) don't need to
 * await it — but awaits the write internally before applying/broadcasting the
 * new consent, so a fast reload can't race an in-flight IndexedDB write and
 * read back the stale value.
 *
 * Applies `consent` itself, in memory, rather than re-reading storage —
 * persistence and application are independent concerns. `idbSet` fails open
 * (private mode, quota, an unsupported browser), so a write can silently not
 * persist; re-deriving the decision from storage would then make an explicit
 * click inert, which is worse than the theatre this control already avoids
 * elsewhere. A choice the visitor just made takes effect now regardless of
 * whether it survives a reload.
 *
 * The dispatch is in a `finally`: `applyConsent`'s dynamic `import("./monitoring")`
 * can itself reject (a chunk failing to load), and the event is what the
 * rendered control listens for to know the request finished — without a
 * guaranteed dispatch, a click during that failure would leave the control
 * waiting forever instead of settling back to an answerable state.
 */
export function setMonitoringConsent(consent: "granted" | "denied"): void {
  void (async () => {
    await idbSet(MONITORING_CONSENT_KEY, consent);
    try {
      await applyConsent(consent);
    } finally {
      window.dispatchEvent(
        new CustomEvent<MonitoringConsent>(MONITORING_CONSENT_EVENT, { detail: consent }),
      );
    }
  })();
}

/**
 * Starts or stops monitoring to match `consent`.
 *
 * Returns without importing anything in the common case — no consent, nothing
 * loaded — so a visitor who never opts in pays nothing for this module beyond
 * one IndexedDB read.
 */
async function applyConsent(consent: MonitoringConsent): Promise<void> {
  const granted = consent === "granted";
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

/**
 * Starts or stops monitoring to match the *stored* answer, for restoring a
 * previously granted choice (e.g. on page load, once something calls this).
 * Returns the resolved consent so callers can reflect it.
 */
export async function applyMonitoringConsent(): Promise<MonitoringConsent> {
  const consent = await readMonitoringConsent();
  await applyConsent(consent);
  return consent;
}
