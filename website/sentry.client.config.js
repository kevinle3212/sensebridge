// Entry point @sentry/astro injects into every page.
//
// It loads this file automatically; it is not imported anywhere. Astro's
// default client config path is `sentry.client.config.(js|ts)` at the project
// root, so renaming or moving this silently disables error reporting.
//
// There is no `sentry.server.config.js` counterpart on purpose: astro.config.mjs
// pins `output: "static"`, so this site has no server runtime for one to run in.
//
// Note what this file does *not* do: it never imports Sentry. On a site that
// ships zero JavaScript by default (see scripts/check-zero-js.js), initialising
// a ~27kB SDK on every visit so that it could sit there disabled would be the
// wrong trade — and "we only send data with your consent" is a weaker promise
// than "without your consent, the code that could send it is never downloaded".
// So the SDK and its options live behind the dynamic import in
// src/scripts/monitoring.ts, and all this does is read one `localStorage` value.
//
// The consent control itself lives on /privacy — see
// src/components/MonitoringConsent.astro and src/components/PrivacyPage.astro.
import { applyMonitoringConsent } from "./src/scripts/monitoring-consent";

// Fire-and-forget: nothing on the page waits for monitoring, and an error
// reporter that delayed first paint would be its own bug. This resolves
// immediately without fetching anything unless consent was granted on an
// earlier visit.
void applyMonitoringConsent();
