/**
 * The Sentry browser SDK and its configuration — the only module on this site
 * that imports it.
 *
 * Reached exclusively through the dynamic `import()` in `./monitoring-consent`,
 * so this whole file (and the ~27kB gzipped SDK it pulls in) is a lazy chunk
 * that a visitor who has not opted in never fetches. Importing it statically
 * anywhere would undo that in one line.
 *
 * Everything here is deliberately the minimum that reports an error and nothing
 * more. This is a static, zero-JS-by-default site for a product whose whole
 * posture is that it does not watch its users, so each Sentry feature that
 * observes a visitor rather than a crash is off:
 *
 *   - Session Replay records the DOM. Not enabled — it is a screen recorder.
 *   - Tracing samples navigation timing per visitor. Not enabled.
 *   - The user-feedback widget injects a dialog into every page. Not enabled.
 *   - `sendDefaultPii` would attach IP address and request headers. Left false.
 *
 * Enabling any of them is a privacy decision, not a config tweak: it needs
 * docs/PRIVACY.md, legal/PRIVACY_POLICY.md, and the disclosure on /privacy
 * updated in the same change, and it may invalidate consent already collected
 * under the narrower description.
 */
import * as Sentry from "@sentry/astro";

/**
 * Whether `Sentry.init` has run in this page's lifetime, so starting twice is a
 * no-op and stopping something never started cannot throw.
 */
let running = false;

/**
 * Public, client-visible, and safe to ship — a DSN is a write-only ingest
 * endpoint, not a credential. It is still read from the environment rather than
 * hardcoded so a fork reports to its own project (or, with the variable unset,
 * to nothing at all). `PUBLIC_` is Astro's prefix for values allowed to reach
 * the browser bundle; anything without it is stripped at build time.
 */
const dsn = import.meta.env.PUBLIC_SENTRY_DSN?.trim();

/**
 * Distinguishes a real deployment's noise from a developer's.
 *
 * Empty-string-aware, matching how astro.config.mjs treats SITE_URL:
 * .env.example ships `PUBLIC_SENTRY_ENVIRONMENT=` blank, and a blank value is
 * *set*, so `??` would hand Sentry an empty environment string instead of
 * falling through.
 */
const configuredEnvironment = import.meta.env.PUBLIC_SENTRY_ENVIRONMENT?.trim();
const environment =
  configuredEnvironment === undefined || configuredEnvironment === ""
    ? "development"
    : configuredEnvironment;

/**
 * Initialises the SDK. Safe to call repeatedly.
 *
 * The `dsn` guard is belt-and-braces: astro.config.mjs only registers the
 * integration when `PUBLIC_SENTRY_DSN` is set, so an unconfigured build never
 * ships the entry point that reaches this module at all.
 */
export function startMonitoring(): void {
  if (running || !dsn) {
    return;
  }
  Sentry.init({
    dsn,
    environment,

    // No IP address, no headers, no cookies. Sentry's default is already false;
    // it is spelled out because this is the single option whose flip would turn
    // a crash reporter into a visitor tracker, and a reviewer should not have to
    // know the default to see that it is off.
    sendDefaultPii: false,

    // Empty integration list, stated explicitly rather than omitted. Omitting it
    // takes Sentry's defaults, which change between minor versions and have
    // previously added new automatic instrumentation. Pinning it to `[]` means a
    // dependency bump can never quietly start collecting something new — it also
    // drops the default Breadcrumbs integration, so no click, navigation, console
    // line, or fetch URL from a visitor's session is recorded or transmitted.
    integrations: [],

    // Discards all trace data. Explicit rather than relying on the default of 0.
    // Note that astro.config.mjs also compiles the tracing code out entirely via
    // `__SENTRY_TRACING__`, so raising this alone would do nothing.
    tracesSampleRate: 0,

    // Errors thrown by browser extensions, injected third-party scripts, and
    // wallet/translation overlays are noise this project cannot act on: they
    // originate outside the site's own bundle. `'self'` in the CSP already
    // blocks such scripts from loading, so anything matching here is running in
    // spite of that and is definitionally not a site bug.
    ignoreErrors: [
      // Fired by Safari and Chrome when a cross-origin script errors; carries no
      // stack, so it is unactionable by construction.
      "Script error.",
      // ResizeObserver's benign "loop limit" warning. Browsers report it as an
      // error; the spec says it is safe to ignore.
      /^ResizeObserver loop/,
    ],

    // Last line of defence before anything leaves the browser. `sendDefaultPii`
    // and the empty integration list already prevent Sentry from *collecting*
    // personal data; this strips the fields that could still carry it if a
    // future SDK version changes a default, so the guarantee does not depend on
    // upstream behaviour staying put.
    beforeSend(event) {
      // Sentry never sets these without `sendDefaultPii`, but deleting them
      // unconditionally means that stays true even if that changes upstream.
      delete event.user;
      delete event.server_name;
      if (event.request) {
        delete event.request.cookies;
        delete event.request.headers;
        delete event.request.data;
        // The path is what makes an error locatable; the query string is where
        // anything user-supplied would be. Keep the former, drop the latter.
        delete event.request.query_string;
        if (typeof event.request.url === "string") {
          // `split` always yields at least one element, but the strict index
          // signature can't know that — hence the fallback rather than a `!`.
          const [pathOnly] = event.request.url.split("?");
          event.request.url = pathOnly ?? event.request.url;
        }
      }
      return event;
    },
  });
  running = true;
}

/**
 * Shuts the SDK down when consent is withdrawn.
 *
 * Closes the client rather than merely muting it, so the error and
 * unhandled-rejection listeners it installed stop receiving events, and any
 * report still queued is dropped instead of flushed. Withdrawn consent should
 * not be followed by one last transmission.
 */
export function stopMonitoring(): void {
  if (!running) {
    return;
  }
  void Sentry.getClient()?.close();
  running = false;
}
