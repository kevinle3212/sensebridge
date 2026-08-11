import SenseBridgeCore
import SwiftUI

/// Root dependency container, injected once at app launch — see
/// docs/ARCHITECTURE.md "State management". Deliberately small: app state
/// is mostly transient perception data plus this settings object, the one
/// shared camera, and the output targets every feature renders through.
@MainActor
@Observable
final class AppEnvironment {
    /// Persists `settings` across launches; injectable so tests/previews can
    /// supply an in-memory store.
    let settingsStore: SettingsStore
    /// The user's current settings; mutating this and calling `save()`
    /// persists the change and pushes it to the output targets below.
    var settings: Settings

    /// The app's single camera session — see `CameraController`.
    let camera: CameraController
    /// Shared speech output, so a rate/pitch/volume change applies to every
    /// feature rather than only the next view to be constructed.
    let speech: SpeechRenderTarget
    /// Shared haptic output, for the same reason as `speech`.
    let haptics: HapticRenderTarget

    /// The most recent `save()` application, so the next one can chain onto
    /// it and preserve ordering — see `save()`.
    private var settingsApplyTask: Task<Void, Never>?

    /// Loads settings from `settingsStore`, resetting to defaults first when
    /// launched under `-uiTestReset`.
    init(settingsStore: SettingsStore = UserDefaultsSettingsStore()) {
        self.settingsStore = settingsStore
        // UI tests launch with `-uiTestReset` to start from a known state
        // instead of whatever a previous test run persisted — never set
        // outside a test target. That known state defaults to
        // onboarding-complete, since most UI tests exercise post-onboarding
        // features and `Settings()`'s own default (`hasCompletedOnboarding:
        // false`) would otherwise land every one of them on `OnboardingView`
        // instead of `HomeView`. Tests that specifically cover onboarding
        // pass `-uiTestShowOnboarding` too, to see it.
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            var fresh = Settings()
            if !ProcessInfo.processInfo.arguments.contains("-uiTestShowOnboarding") {
                fresh.hasCompletedOnboarding = true
            }
            settingsStore.save(fresh)
        }
        let loaded = settingsStore.load()
        settings = loaded
        camera = CameraController()
        speech = SpeechRenderTarget(
            language: loaded.language,
            voiceSettings: SpeechVoiceSettings(
                rate: loaded.speechRate,
                pitch: loaded.speechPitch,
                volume: loaded.speechVolume
            )
        )
        haptics = HapticRenderTarget(
            enabled: loaded.hapticsEnabled,
            intensity: loaded.hapticIntensity
        )

        // Started here, at the first moment settings are known, so a crash in
        // the rest of launch is still caught — but only for a user who already
        // opted in on a previous run. `apply` no-ops when this build carries no
        // DSN, which is every build that has not configured one.
        CrashReporting.apply(isEnabled: loaded.crashReportingEnabled)

        // Deliberately no fallback here. An earlier version substituted
        // `selectableProfiles.first` for an undeliverable persisted profile
        // and saved it — which is `.blind`, so a Deaf user was silently
        // rerouted to speech, the one channel their profile declares they
        // cannot receive, and their stored choice was destroyed in the
        // process. A profile is a claim about which senses someone has, not a
        // cosmetic default: it is never ours to quietly rewrite. The choice
        // is kept as stored, `undeliverableChannels` reports the gap, and the
        // UI is responsible for saying so out loud.
    }

    /// The render target registered for each channel. `.caption` is
    /// deliberately absent: no caption `RenderTarget` exists yet, and
    /// registering a placeholder would make the gap invisible.
    private var renderTargets: [RenderChannel: any RenderTarget] {
        [.speech: speech, .haptic: haptics]
    }

    /// Fan-out target for the current output profile — what every feature
    /// renders through. Recomputed per access: `MultiRenderTarget` is a small
    /// value type, so this costs nothing and can't go stale when the user
    /// switches profile.
    var output: MultiRenderTarget {
        MultiRenderTarget(profile: settings.outputProfile, targets: renderTargets)
    }

    /// The output profiles this build can actually deliver on, derived from
    /// `renderTargets` rather than hardcoded — so `.deaf` starts appearing on
    /// its own the day a caption `RenderTarget` is registered. Offering a
    /// profile whose channels render nothing is the kind of silent failure
    /// docs/SAFETY-FRAMING.md forbids.
    var selectableProfiles: [OutputProfile] {
        OutputProfile.allCases.filter { profile in
            MultiRenderTarget(profile: profile, targets: renderTargets).unsupportedChannels.isEmpty
        }
    }

    /// Options for the output-profile picker: everything deliverable, plus
    /// the user's current choice when it isn't. A stored selection is never
    /// dropped from the list — a `Picker` whose selection is absent from its
    /// own options renders blank, which reads as "unset" when the truth is
    /// "unsupported".
    var outputProfileOptions: [OutputProfile] {
        var options = selectableProfiles
        if !options.contains(settings.outputProfile) {
            options.append(settings.outputProfile)
        }
        return options
    }

    /// Profiles this build cannot deliver and the user has not selected —
    /// what the app intends to support but has not built yet.
    ///
    /// Surfaced rather than hidden, per AGENTS.md doctrine 4: a capability
    /// that simply never appears teaches the user nothing, whereas one named
    /// as unavailable tells them the option exists and why it is absent. The
    /// user's own selection is excluded because a warning row already covers
    /// it in more detail.
    var unavailableProfiles: [OutputProfile] {
        OutputProfile.allCases.filter { profile in
            profile != settings.outputProfile && !selectableProfiles.contains(profile)
        }
    }

    /// Channels `profile` prefers that this build cannot deliver. Non-empty
    /// means the user would receive nothing on those channels, and the UI must
    /// say so rather than look like it is working.
    func undeliverableChannels(for profile: OutputProfile) -> Set<RenderChannel> {
        MultiRenderTarget(profile: profile, targets: renderTargets).unsupportedChannels
    }

    /// `undeliverableChannels(for:)` applied to the active profile.
    var undeliverableChannels: Set<RenderChannel> {
        output.unsupportedChannels
    }

    /// Channels the active profile prefers that would currently reach the user
    /// with nothing — whether because no target is registered for them
    /// (`undeliverableChannels`) or because the user's own settings have
    /// silenced them.
    ///
    /// A registered target is not the same as an audible one:
    /// `HapticRenderTarget.render` returns immediately while disabled, and a
    /// zero intensity or volume scales every cue to nothing. Both look exactly
    /// like working output from the outside.
    var silentChannels: Set<RenderChannel> {
        var silent = undeliverableChannels
        if !settings.hapticsEnabled || settings.hapticIntensity <= 0 {
            silent.insert(.haptic)
        }
        if settings.speechVolume <= 0 {
            silent.insert(.speech)
        }
        return silent.intersection(settings.outputProfile.preferredChannels)
    }

    /// Whether the current profile-and-settings combination would deliver
    /// nothing at all — every channel the profile prefers is silent.
    ///
    /// The realistic path is `.deafBlind` with haptics switched off: the app
    /// keeps running, every capture "succeeds", and not one result reaches the
    /// user. Silence is indistinguishable from "nothing was found" on a
    /// tactile-only channel, so this has to be stated in the UI rather than
    /// left for the user to infer.
    var deliversNoOutput: Bool {
        let preferred = settings.outputProfile.preferredChannels
        return !preferred.isEmpty && silentChannels == preferred
    }

    /// Whether the active profile's channels carry only signals, never the
    /// recognized text. True for `.deafBlind`, whose sole channel is haptic —
    /// `HapticRenderTarget` renders `OutputMessage.signal` and discards
    /// `text`. The user gets "a result is ready", never the result.
    var deliversCuesWithoutText: Bool {
        settings.outputProfile.preferredChannels.isDisjoint(with: [.speech, .caption])
    }

    /// Persists the current `settings` and pushes the voice and haptic
    /// portions to the shared targets, which hold their own copies.
    func save() {
        settingsStore.save(settings)
        // Takes effect on the toggle, not on the next launch. Consent that
        // needs a relaunch to be honoured is not consent — a user who switches
        // reporting off expects it off now, and one who switches it on expects
        // the next crash to be caught.
        CrashReporting.apply(isEnabled: settings.crashReportingEnabled)
        let voice = SpeechVoiceSettings(
            rate: settings.speechRate,
            pitch: settings.speechPitch,
            volume: settings.speechVolume
        )
        let language = settings.language
        let hapticsEnabled = settings.hapticsEnabled
        let hapticIntensity = settings.hapticIntensity
        // Chained onto the previous application rather than fired off
        // independently. A settings slider calls `save()` on every drag tick,
        // and independent unstructured `Task`s reach an actor in
        // nondeterministic order — so an older rate could land after a newer
        // one and stick, leaving the voice at a value the user had already
        // dragged past. Awaiting the predecessor makes the actors see the
        // values in the order the user produced them.
        let previous = settingsApplyTask
        settingsApplyTask = Task { [speech, haptics] in
            await previous?.value
            await speech.setLanguage(language)
            await speech.setVoiceSettings(voice)
            await haptics.setEnabled(hapticsEnabled)
            await haptics.setIntensity(hapticIntensity)
        }
    }
}
