import SenseBridgeCore
import SwiftUI

/// How near something has to be before hands-free awareness mentions it, and
/// whether the proximity pulse runs.
///
/// On the Awareness screen rather than only in Settings. The right threshold
/// depends on how the phone is mounted and how fast the person walks, and
/// neither is knowable until they are actually walking — sending them to
/// another screen to find out is how a tunable ends up never tuned.
///
/// Its own `View` rather than a computed property on `ObstacleAwarenessView`,
/// which SwiftLint's `type_body_length` gate had already outgrown.
struct AwarenessSensitivitySection: View {
    /// Shared app state — the settings this section writes are the same ones
    /// `AmbientAwarenessSession` reads when it starts.
    @Environment(AppEnvironment.self) private var environment

    /// The language chosen in Settings, so the distance is formatted in the
    /// units the user actually reads — not the process locale.
    private var displayLocale: Locale {
        environment.settings.language.locale ?? .current
    }

    var body: some View {
        @Bindable var environment = environment
        return Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(alertDistanceLabel)
                    .font(.callout)
                Slider(
                    value: $environment.settings.awarenessAlertDistanceMeters,
                    in: 0.5 ... 4,
                    step: 0.25
                ) {
                    Text("Alert distance")
                } minimumValueLabel: {
                    Text("Nearer")
                } maximumValueLabel: {
                    Text("Further")
                }
                .accessibilityValue(alertDistanceLabel)
                .accessibilityHint("Sets how near something has to be before it is mentioned.")
                .onChange(of: environment.settings.awarenessAlertDistanceMeters) { _, _ in
                    environment.save()
                }
            }
            Toggle("Pulse faster as things get nearer", isOn: $environment.settings.awarenessProximityHapticsEnabled)
                .onChange(of: environment.settings.awarenessProximityHapticsEnabled) { _, _ in
                    environment.save()
                }
                .accessibilityHint("""
                Repeats the awareness buzz, faster the nearer the measurement. \
                Runs only while an alert is already active.
                """)
            // Stated rather than left implicit: a threshold change during a run
            // would otherwise appear to do nothing, which reads as a broken
            // control.
            Text("A new distance applies the next time hands-free awareness starts.")
                .font(.footnote)
                .foregroundStyle(Color("SecondaryText"))
        } header: {
            Text("Sensitivity")
                .foregroundStyle(Color("SecondaryText"))
        }
    }

    /// The alert threshold in the reader's own units.
    private var alertDistanceLabel: String {
        let distance = AmbientAwarenessSession.formattedDistance(
            meters: environment.settings.awarenessAlertDistanceMeters, locale: displayLocale
        )
        return String(
            localized: "Mention things within about \(distance)",
            comment: "Label for the awareness alert-distance slider."
        )
    }
}

#Preview {
    List {
        AwarenessSensitivitySection()
    }
    .environment(AppEnvironment())
}
