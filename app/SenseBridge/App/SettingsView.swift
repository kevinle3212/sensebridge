import SenseBridgeCore
import SwiftUI

/// User-configurable preferences, sectioned by the feature they affect. Every
/// binding mutates `environment.settings` then calls `environment.save()`,
/// which persists the change and pushes it to the shared speech/haptic
/// targets — see `AppEnvironment.save()`.
struct SettingsView: View {
    /// Shared app state, read here for the current settings and written back
    /// via `save()` when the user changes one.
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Form {
            Section {
                sliderRow(
                    "Speech rate",
                    value: binding(\.speechRate),
                    hint: "How fast the voice speaks."
                )
                sliderRow(
                    "Speech pitch",
                    value: binding(\.speechPitch),
                    hint: "How high or low the voice sounds."
                )
                sliderRow(
                    "Speech volume",
                    value: binding(\.speechVolume),
                    hint: "How loud the voice speaks.",
                    // Floored, not `0...1`. Speech is the only channel the
                    // default profile has, so a slider that reaches zero lets
                    // a user silence the entire app from a control labelled
                    // "volume" — and then read the silence as "nothing was
                    // found". Turning output off is what the output profile is
                    // for, and that choice is explicit.
                    in: Self.minimumSpeechVolume ... 1
                )
                Button("Preview voice") {
                    Task {
                        await environment.speech.render(
                            OutputMessage(
                                text: "This is a preview of SenseBridge's voice.",
                                signal: .resultReady
                            )
                        )
                    }
                }
                .accessibilityHint("Speaks a sample sentence using the current speech settings.")
            } header: {
                Text("Speech")
                    .foregroundStyle(Color("SecondaryText"))
            }
            Section {
                Toggle("Enable haptics", isOn: binding(\.hapticsEnabled))
                sliderRow(
                    "Haptic intensity",
                    value: binding(\.hapticIntensity),
                    hint: environment.settings.hapticsEnabled
                        ? "How strong haptic cues feel."
                        : "Unavailable while haptics are switched off."
                )
                .disabled(!environment.settings.hapticsEnabled)
                Button("Preview haptic") {
                    Task { await environment.haptics.render(OutputMessage(text: "", signal: .resultReady)) }
                }
                // `HapticRenderTarget.render` is a no-op while disabled, so
                // an enabled button here would be a control that silently
                // does nothing — the failure mode this app must not have.
                .disabled(!environment.settings.hapticsEnabled)
                .accessibilityHint(
                    environment.settings.hapticsEnabled
                        ? "Plays a sample haptic cue using the current haptic settings."
                        : "Unavailable while haptics are switched off."
                )
            } header: {
                Text("Haptics")
                    .foregroundStyle(Color("SecondaryText"))
            } footer: {
                Text("Haptics are unavailable in the Simulator and feel different across devices.")
                    .foregroundStyle(Color("SecondaryText"))
            }
            Section {
                Picker("Preferred lens", selection: binding(\.preferredLens)) {
                    ForEach(CameraLens.allCases, id: \.self) { lens in
                        Text(displayName(for: lens))
                            .tag(lens)
                    }
                }
                .accessibilityHint("Chooses which camera lens capture starts with, where available.")
                Toggle("Torch on by default", isOn: binding(\.torchDefaultOn))
            } header: {
                Text("Camera")
                    .foregroundStyle(Color("SecondaryText"))
            } footer: {
                Text("Not every device has every lens. This preference is applied only where the hardware supports it.")
                    .foregroundStyle(Color("SecondaryText"))
            }
            AwarenessSettingsSection(
                narrationIntervalSeconds: binding(\.narrationIntervalSeconds),
                alertDistanceMeters: binding(\.awarenessAlertDistanceMeters)
            )
            DetailLevelSettingsSection(spokenDetail: binding(\.spokenDetail))
            ReasoningBackendSettingsView(
                reasoningBackend: binding(\.reasoningBackend),
                cloudProvider: binding(\.cloudProvider),
                localEndpointURL: binding(\.localEndpointURL),
                reasoningModelOverride: binding(\.reasoningModelOverride),
                narrationIntervalSeconds: environment.settings.narrationIntervalSeconds
            )
            Section {
                Picker("Output profile", selection: binding(\.outputProfile)) {
                    // `outputProfileOptions`, not `selectableProfiles`: a
                    // stored profile this build can't deliver must still
                    // appear, or the picker renders blank and reads as "unset"
                    // when the truth is "unsupported".
                    ForEach(environment.outputProfileOptions, id: \.self) { profile in
                        Text(displayName(for: profile))
                            .tag(profile)
                    }
                }
                .accessibilityHint("Chooses which senses SenseBridge delivers output through.")
                // Stated in the list itself, not only in the footer. A footer
                // is trailing context a VoiceOver user reaches after the
                // control; these are conditions under which the app delivers
                // less than it appears to, and they have to be encountered
                // before the choice is made, not after.
                if environment.deliversNoOutput {
                    warningRow(
                        """
                        With these settings SenseBridge will not deliver results at all. \
                        Every channel this profile uses is switched off or unavailable, so \
                        silence will not mean nothing was found.
                        """
                    )
                } else if !environment.undeliverableChannels.isEmpty {
                    warningRow(
                        """
                        Part of this profile can't be delivered yet, so some results will not \
                        reach you. Silence does not mean nothing was found.
                        """
                    )
                } else if environment.deliversCuesWithoutText {
                    warningRow(
                        """
                        This profile delivers short vibration cues only — enough to tell that \
                        a result arrived, an error happened, or something may be ahead. It does \
                        not deliver the recognized text itself, and these cues are not a haptic \
                        language.
                        """
                    )
                }
                // Named, not hidden — AGENTS.md doctrine 4. A profile that
                // simply never appears teaches the user nothing; one listed as
                // unavailable tells them the option is intended and why it
                // isn't here. Derived from the real target registry, so each
                // row disappears by itself the day its channel is built.
                ForEach(environment.unavailableProfiles, id: \.self) { profile in
                    UnavailableProfileRow(
                        name: displayName(for: profile),
                        reason: unavailableReason(for: profile)
                    )
                }
            } header: {
                Text("Output")
                    .foregroundStyle(Color("SecondaryText"))
            }
            Section {
                Picker("Language", selection: binding(\.language)) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(displayName(for: language))
                            .tag(language)
                    }
                }
                .accessibilityHint("Choose the app's display language.")
            } header: {
                Text("Language")
                    .foregroundStyle(Color("SecondaryText"))
            }
            Section {
                Button("Replay walkthrough") {
                    environment.settings.hasCompletedOnboarding = false
                    environment.save()
                }
                .accessibilityHint("Shows the first-run welcome and permission walkthrough again.")
            } header: {
                Text("Help")
                    .foregroundStyle(Color("SecondaryText"))
            }
            DiagnosticsSettingsSection(crashReportingEnabled: binding(\.crashReportingEnabled))
        }
        .navigationTitle("Settings")
    }

    /// The lowest speech volume the slider offers — see its call site for why
    /// it is not zero.
    private static let minimumSpeechVolume = 0.1

    /// A labeled slider, with a percent `accessibilityValue` so VoiceOver
    /// announces the current setting rather than a raw fraction. `range`
    /// defaults to the full `0...1`; pass a narrower one where zero would
    /// silently disable a channel.
    private func sliderRow(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        hint: LocalizedStringKey,
        in range: ClosedRange<Double> = 0 ... 1
    ) -> some View {
        VStack(alignment: .leading) {
            // Visible for sighted users, hidden from VoiceOver: the slider
            // below already carries `title` as its label, and leaving both in
            // the tree makes VoiceOver announce the name twice per row.
            Text(title)
                .accessibilityHidden(true)
            Slider(value: value, in: range)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded()))%")
                .accessibilityHint(hint)
        }
    }

    /// A two-way binding onto one field of `environment.settings` that
    /// persists on every write.
    ///
    /// Written once, generically, rather than nine near-identical properties:
    /// every control on this screen has the same read-mutate-`save()` shape,
    /// and nine copies of it is nine places for a future field to be added
    /// without its `save()`, which fails silently — the control moves, the
    /// preference is lost at relaunch.
    private func binding<Value>(_ keyPath: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(
            get: { environment.settings[keyPath: keyPath] },
            set: { newValue in
                environment.settings[keyPath: keyPath] = newValue
                environment.save()
            }
        )
    }
}

/// Picker labels.
///
/// An extension rather than more of the main body: these are pure
/// value-to-label maps with no view state, and keeping them here holds
/// `SettingsView` under the 200-line type-body limit without splitting the
/// screen's actual layout across two files.
extension SettingsView {
    /// A row stating a way the app currently delivers less than it appears to.
    ///
    /// The icon is decorative and hidden: VoiceOver would otherwise read
    /// "exclamation mark triangle" before the sentence that actually carries
    /// the meaning. The `Important:` prefix on the accessibility label does
    /// that job instead, because a colour and a glyph convey nothing here.
    func warningRow(_ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
                .font(.callout)
        } icon: {
            // Without an explicit scalable font, SF Symbols render at a fixed
            // point size and don't grow with the paired text at larger
            // Dynamic Type sizes.
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Important: \(Text(text))"))
    }

    /// Why `profile` can't be delivered, phrased for the channel that is
    /// missing rather than hardcoded per profile.
    func unavailableReason(for profile: OutputProfile) -> LocalizedStringKey {
        let missing = environment.undeliverableChannels(for: profile)
        if missing.contains(.caption) {
            return "Captions aren't built yet."
        }
        if missing.contains(.haptic) {
            return "Haptic output isn't available on this device."
        }
        return "Speech output isn't available on this device."
    }

    /// Localized label shown in the language picker for `language`.
    func displayName(for language: AppLanguage) -> LocalizedStringKey {
        switch language {
        case .system: "System"
        case .en: "English"
        case .es: "Español"
        case .vi: "Tiếng Việt"
        }
    }

    /// Localized label shown in the lens picker for `lens`, matching
    /// `CameraControlsView.displayName(for:)` — duplicated rather than
    /// shared, since it's three one-word labels used from two views.
    func displayName(for lens: CameraLens) -> LocalizedStringKey {
        switch lens {
        case .ultraWide: "Ultra-wide"
        case .wide: "Wide"
        case .telephoto: "Telephoto"
        }
    }

    /// Localized label shown in the output profile picker for `profile`.
    func displayName(for profile: OutputProfile) -> LocalizedStringKey {
        switch profile {
        case .blind: "Blind"
        case .deafBlind: "Deaf-blind"
        case .deaf: "Deaf"
        }
    }
}
