import SenseBridgeCore
import SwiftUI

// Split out of SettingsView.swift, which had grown past the 400-line file and
// 200-line type-body limits. These were already standalone views; only their
// location changed.
//
// Both are `internal` rather than `private`. At file scope Swift treats
// `private` as `fileprivate`, so keeping the original modifier made them
// invisible to SettingsView.swift the moment they moved out of it — the build
// failed with "cannot find … in scope". Neither is `public`; the app target is
// still the boundary.

/// A row naming an output profile the app intends to support but cannot
/// deliver yet, with the reason.
///
/// Deliberately not a `Picker` entry: selecting it would deliver nothing, and
/// a control that silently does nothing is worse than an absent one for a
/// VoiceOver user — see AGENTS.md doctrine 4's first corollary. Listing it
/// here instead satisfies the second: the option is named, and so is its
/// absence.
struct UnavailableProfileRow: View {
    /// The profile's display name, resolved by the caller so this view needs
    /// no knowledge of `OutputProfile`.
    let name: LocalizedStringKey
    /// Why the profile can't be delivered.
    let reason: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
            Text(reason)
                .font(.caption)
                .foregroundStyle(Color("SecondaryText"))
        }
        // Combined into one element with an explicit label: read separately,
        // the name announces as if it were an available choice, and the
        // caveat only arrives on the next swipe.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(Text(name)), not yet available. \(Text(reason))"))
    }
}

/// The two knobs that shape hands-free awareness.
///
/// A separate `View` rather than another section inlined into `SettingsView`
/// for the same reason the generic `binding(_:)` helper exists there: this
/// screen accumulates a section per subsystem, and `SettingsView`'s body had
/// already reached its length budget. Both controls need a value formatter
/// `sliderRow`'s percentage cannot provide, so the helper travels with them.
struct AwarenessSettingsSection: View {
    @Binding var narrationIntervalSeconds: Double
    @Binding var alertDistanceMeters: Double

    var body: some View {
        Section {
            measuredSliderRow(
                "Time between descriptions",
                value: $narrationIntervalSeconds,
                in: 3 ... 20,
                format: { "\(Int($0.rounded())) seconds" },
                hint: """
                Sets how often hands-free awareness describes the surroundings. \
                Alerts about something close by are not delayed by this.
                """
            )
            measuredSliderRow(
                "Alert distance",
                value: $alertDistanceMeters,
                in: 0.5 ... 4,
                format: Self.distanceDescription,
                hint: """
                Sets how near something has to be before hands-free awareness \
                mentions it.
                """
            )
        } header: {
            Text("Awareness")
                .foregroundStyle(Color("SecondaryText"))
        } footer: {
            // The right values depend on the mount angle and walking pace,
            // which no default can know — so say that, rather than implying the
            // shipped numbers were tuned for this user.
            Text("""
            These affect hands-free awareness. The best values depend on how you carry \
            the phone and how fast you walk, so expect to adjust them. Awareness is \
            not a safety or mobility feature.
            """)
            .foregroundStyle(Color("SecondaryText"))
        }
    }

    /// A labeled slider over a real-world quantity rather than a `0...1`
    /// fraction.
    ///
    /// Distinct from `SettingsView.sliderRow` because that one announces a
    /// percentage, and "40%" is meaningless for a distance or a duration —
    /// VoiceOver has to say "1.5 metres", which is also the only form the user
    /// can weigh against the room they are standing in.
    private func measuredSliderRow(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        format: @escaping (Double) -> String,
        hint: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading) {
            // Visible for sighted users, hidden from VoiceOver: the slider
            // below already carries `title` as its label, and leaving both in
            // the tree makes VoiceOver announce the name twice per row.
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue))
                    .foregroundStyle(Color("SecondaryText"))
            }
            .accessibilityHidden(true)
            Slider(value: value, in: range)
                .accessibilityLabel(title)
                .accessibilityValue(format(value.wrappedValue))
                .accessibilityHint(hint)
        }
    }

    /// Formats a distance in the reader's own units, so a US user reads feet
    /// rather than a metric figure they have to convert while walking.
    private static func distanceDescription(meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}

#Preview {
    SettingsView()
        .environment(AppEnvironment())
}
