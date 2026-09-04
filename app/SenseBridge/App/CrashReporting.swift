import Foundation
import Sentry

/// Crash reporting for the app, behind an explicit runtime consent gate.
///
/// SenseBridge's architecture has no backend and sends nothing off-device for
/// perception or reasoning (see `docs/ARCHITECTURE.md`). This is the one
/// deliberate exception, and it is built so that the exception cannot happen by
/// accident. Two independent conditions must both hold before a single byte
/// leaves the device:
///
/// 1. A DSN was configured at **build** time (`Config/Sentry.xcconfig` →
///    `Info.plist` → `SentryDSN`). A fresh clone has none, so a contributor's
///    build reports nowhere no matter what they tap.
/// 2. The user switched on **Settings → Diagnostics → Send crash reports**,
///    which is `false` by default and stays false until they change it. This is
///    the consent gate; see `Settings.crashReportingEnabled`.
///
/// This lives in the App layer rather than in `SenseBridgeCore` on purpose. The
/// core package holds the perception and reasoning domain and must stay
/// framework-independent under the protocol-seams invariant, so a third-party
/// SDK belongs out here with the other side-effecting adapters. `Settings` still
/// carries the preference, because that is the app's one persisted-preferences
/// type — a `Bool` is not a framework dependency.
///
/// What is sent when it *is* on: a crash or hang report — stack frames, the
/// exception type and message, OS and device model, and the app version. What
/// is never sent: breadcrumbs (dropped wholesale, below), screenshots, view
/// hierarchies, network activity, IP address, device name, or anything the
/// camera, microphone, or LiDAR ever saw. See `docs/PRIVACY.md`.
@MainActor
enum CrashReporting {
    /// Whether the SDK is currently running, so `apply(isEnabled:)` can be
    /// called on every settings write without restarting or double-closing it.
    private static var isRunning = false

    /// The DSN baked in at build time, or `nil` when none was configured.
    ///
    /// Read from `Info.plist` rather than a Swift constant so the value comes
    /// from the gitignored `Config/Sentry.local.xcconfig` and never lands in a
    /// tracked source file. A blank `SENTRY_DSN` produces an empty string here,
    /// not a missing key, so emptiness is checked rather than presence.
    static var configuredDSN: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Whether this build could report at all if the user consented — used by
    /// `SettingsView` to say so plainly rather than offer a switch that does
    /// nothing. A control that silently has no effect is the exact failure mode
    /// `AGENTS.md` doctrine 4 forbids.
    static var isConfigured: Bool {
        configuredDSN != nil
    }

    /// Starts or stops reporting to match the user's current choice.
    ///
    /// Safe to call on every `AppEnvironment.save()`: it is idempotent, and it
    /// no-ops entirely when no DSN was configured.
    static func apply(isEnabled: Bool) {
        guard let dsn = configuredDSN else { return }
        if isEnabled {
            guard !isRunning else { return }
            start(dsn: dsn)
            isRunning = true
        } else {
            guard isRunning else { return }
            // Tears the SDK down rather than merely muting it, so opting back
            // out ends the installed signal and exception handlers instead of
            // leaving a disabled client attached for the rest of the process.
            SentrySDK.close()
            isRunning = false
        }
    }

    /// Configures and starts the SDK.
    ///
    /// Every option below that observes the *user* rather than the *crash* is
    /// switched off explicitly, including the ones Sentry already defaults to
    /// off. Spelling them out is the point: a reviewer should be able to read
    /// this block and see the whole data-collection surface without knowing any
    /// SDK defaults, and a dependency bump that changes a default cannot
    /// quietly widen it.
    private static func start(dsn: String) {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment

            // No IP address, no username, no device name, no request headers.
            // The single option whose flip would turn a crash reporter into a
            // tracker.
            options.sendDefaultPii = false

            // Screenshots and view hierarchies of a blind user's screen mid-use
            // are exactly the kind of capture this product exists not to do.
            options.attachScreenshot = false
            options.attachViewHierarchy = false

            // Breadcrumbs record taps, view transitions, console lines, and
            // network calls — a behavioural trace of a session. Off at the
            // source, capped at zero, and dropped again in the hook below;
            // three redundant switches because one upstream default change
            // should not be able to start transmitting a usage trail.
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false
            options.maxBreadcrumbs = 0
            options.beforeBreadcrumb = { _ in nil }

            // Performance tracing samples timing per session and needs
            // swizzling to collect it. Neither is wanted: on-device latency is
            // measured on the device by the performance gate, not by watching
            // users. Disabling swizzling also shrinks the runtime surface this
            // SDK touches to the crash handlers alone.
            options.enableAutoPerformanceTracing = false
            options.enableUserInteractionTracing = false
            options.enableNetworkTracking = false
            options.enableCaptureFailedRequests = false
            options.enableSwizzling = false
            options.tracesSampleRate = 0

            // Main-thread hangs are the one non-crash signal kept, because
            // "the UI stopped responding to VoiceOver" is a first-class defect
            // for this app (see the main-thread invariant in CLAUDE.md) and the
            // report describes the app's own stack, not the user.
            options.enableAppHangTracking = true

            // Last line of defence. The options above stop Sentry from
            // *collecting* personal data; this strips anything that could still
            // carry it, so the guarantee does not depend on upstream behaviour
            // staying put.
            options.beforeSend = { event in scrub(event) }
        }
    }

    /// Removes every field that could carry personal data from `event`.
    ///
    /// Returns the same instance mutated, matching Sentry's `beforeSend`
    /// contract (returning `nil` there would discard the report entirely).
    /// Split out from `start(dsn:)` so it can be tested without starting the
    /// SDK — see `CrashReportingTests`.
    ///
    /// Not scrubbed, deliberately: the exception type and message, which are
    /// what make a crash diagnosable. This is safe only because the logging
    /// rule in `docs/ARCHITECTURE.md` already forbids recognized text, images,
    /// and audio from appearing in any message the app constructs. If that rule
    /// is ever relaxed, this function is where the consequence lands.
    ///
    /// `nonisolated`: Sentry runs `beforeSend` on its own background thread, so
    /// this must be callable off the main actor. It touches no actor-isolated
    /// state — only the `event` it is handed — so dropping the enum's `@MainActor`
    /// isolation here is safe.
    nonisolated static func scrub(_ event: Event) -> Event {
        event.user = nil
        event.serverName = nil
        event.request = nil
        event.breadcrumbs = nil
        if var context = event.context {
            // "Kevin's iPhone" is a name, not a device model. The model itself
            // stays — it is what makes a crash reproducible.
            context["device"]?["name"] = nil
            // Locale, timezone, and calendar together narrow a user far more
            // than they help diagnose a stack trace.
            context["culture"] = nil
            event.context = context
        }
        return event
    }

    /// Separates a real installation's reports from a developer's, without a
    /// separate build flag: `DEBUG` is set by the Debug configuration only.
    private static var environment: String {
        #if DEBUG
            return "development"
        #else
            return "production"
        #endif
    }
}
