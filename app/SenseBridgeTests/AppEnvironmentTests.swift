import SenseBridgeCore
import Testing
@testable import SenseBridge

struct AppEnvironmentTests {
    @MainActor
    @Test
    func defaultsToBlindProfileOnFirstLaunch() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore())
        #expect(environment.settings.outputProfile == .blind)
    }

    @MainActor
    @Test
    func offersEveryProfileWhoseChannelHasATarget() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore())
        #expect(environment.selectableProfiles.contains(.deaf))
        #expect(environment.selectableProfiles.contains(.blind))
    }

    @MainActor
    @Test
    func hasNoUndeliverableProfilesWhenEveryChannelIsRegistered() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore())
        #expect(environment.unavailableProfiles.isEmpty)
        #expect(environment.undeliverableChannels(for: .deaf).isEmpty)
        #expect(environment.undeliverableChannels(for: .deafBlind).isEmpty)
    }

    @MainActor
    @Test
    func keepsTheDeafProfileAvailableWhenItIsStored() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore(Settings(outputProfile: .deaf)))
        #expect(environment.unavailableProfiles.isEmpty)
        #expect(environment.outputProfileOptions.contains(.deaf))
    }

    @MainActor
    @Test
    func deafProfileHasNoMissingChannels() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore(Settings(outputProfile: .deaf)))
        #expect(environment.outputProfileOptions.contains(.deaf))
        #expect(environment.undeliverableChannels.isEmpty)
    }

    @MainActor
    @Test
    func doesNotRewriteAnUndeliverableStoredProfile() {
        let store = InMemorySettingsStore(Settings(outputProfile: .deaf))
        let environment = AppEnvironment(settingsStore: store)
        // A profile is a claim about which senses someone has. Substituting
        // `.blind` would reroute a Deaf user to speech and destroy their
        // stored choice in the process.
        #expect(environment.settings.outputProfile == .deaf)
        #expect(store.load().outputProfile == .deaf)
    }

    @MainActor
    @Test
    func reportsWhenNoChannelWouldDeliverAnything() {
        let environment = AppEnvironment(
            settingsStore: InMemorySettingsStore(Settings(outputProfile: .deafBlind, hapticsEnabled: false))
        )
        #expect(environment.deliversNoOutput)
        #expect(environment.silentChannels == [.haptic])
    }

    @MainActor
    @Test
    func treatsZeroHapticIntensityAsSilentNotMerelyQuiet() {
        let environment = AppEnvironment(
            settingsStore: InMemorySettingsStore(Settings(outputProfile: .deafBlind, hapticIntensity: 0))
        )
        #expect(environment.deliversNoOutput)
    }

    @MainActor
    @Test
    func aWorkingHapticProfileIsNotReportedAsSilent() {
        let environment = AppEnvironment(
            settingsStore: InMemorySettingsStore(Settings(outputProfile: .deafBlind))
        )
        #expect(!environment.deliversNoOutput)
        // Still cue-only: the haptic channel carries the signal, never the text.
        #expect(environment.deliversCuesWithoutText)
    }

    @MainActor
    @Test
    func speechProfileCarriesTheTextItself() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore())
        #expect(!environment.deliversCuesWithoutText)
        #expect(!environment.deliversNoOutput)
    }

    @MainActor
    @Test
    func captionTargetReplacesAndClearsTheCurrentCaption() async {
        let target = CaptionRenderTarget()

        await target.render(OutputMessage(text: "It looks like a chair.", signal: .resultReady))
        #expect(target.text == "It looks like a chair.")

        await target.render(OutputMessage(text: " ", signal: .captureTaken))
        #expect(target.text == nil)

        await target.render(OutputMessage(text: "  Padded.\n", signal: .resultReady))
        #expect(target.text == "Padded.")
    }

    @MainActor
    @Test
    func captionOverlayGateMatchesTheChannelThatReceivesTheText() {
        // `CaptionOverlay` shows itself on this condition rather than on a
        // hardcoded profile list, so a profile that starts receiving caption
        // text can never be one the overlay declines to draw.
        for profile in OutputProfile.allCases {
            let environment = AppEnvironment(settingsStore: InMemorySettingsStore(Settings(outputProfile: profile)))
            let wantsCaptions = profile.preferredChannels.contains(.caption)
            #expect(wantsCaptions == (profile == .deaf))
            #expect(environment.undeliverableChannels.isEmpty)
        }
    }
}

private final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private var stored: Settings

    init(_ initial: Settings = Settings()) {
        stored = initial
    }

    func load() -> Settings {
        stored
    }

    func save(_ settings: Settings) {
        stored = settings
    }
}
