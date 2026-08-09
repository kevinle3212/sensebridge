import SwiftUI

/// The one control for opt-in crash reporting.
///
/// A separate `View` rather than another section inlined into `SettingsView`
/// for the same reason `AwarenessSettingsSection` is: this screen accumulates
/// a section per subsystem, and `SettingsView`'s body had already reached its
/// length budget.
struct DiagnosticsSettingsSection: View {
    @Binding var crashReportingEnabled: Bool

    var body: some View {
        Section {
            Toggle("Send crash reports", isOn: $crashReportingEnabled)
                // A switch that cannot do anything is worse than an absent
                // one: it reads as consent given and honoured. Builds
                // without a DSN say so in the row below instead.
                .disabled(!CrashReporting.isConfigured)
                .accessibilityHint(
                    CrashReporting.isConfigured
                        ? """
                        Sends a report to the developer when SenseBridge crashes or freezes. \
                        Off unless you turn it on.
                        """
                        : "Unavailable in this build, which has no reporting service configured."
                )
            if !CrashReporting.isConfigured {
                // Named, not hidden — AGENTS.md doctrine 4, the same
                // reasoning as the unavailable output profiles in SettingsView.
                warningRow(
                    """
                    This build has no crash-reporting service configured, so nothing can \
                    be sent even with this switched on.
                    """
                )
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            // The whole disclosure, in the place the choice is made. A
            // privacy policy a blind user has to leave the app to find is
            // not where consent should be informed.
            Text(
                """
                Off by default. When on, SenseBridge sends the developer a report if it \
                crashes or freezes: where in the code it happened, your iPhone model, and \
                the iOS and app versions. It never sends camera images, what the camera \
                read, audio, your location, your name, or your IP address, and it never \
                records what you do in the app. Turn it off at any time and reporting \
                stops immediately.
                """
            )
        }
    }

    /// A row stating a way the app currently delivers less than it appears to.
    ///
    /// Duplicated from `SettingsView.warningRow` rather than shared — see
    /// `AwarenessSettingsSection.measuredSliderRow` for why a one-call-site
    /// helper travels with the view that uses it instead of being hoisted.
    private func warningRow(_ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
                .font(.callout)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Important: \(Text(text))"))
    }
}
