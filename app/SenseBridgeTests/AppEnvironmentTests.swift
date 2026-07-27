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
    func doesNotOfferProfilesWhoseChannelsHaveNoTarget() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore())
        #expect(!environment.selectableProfiles.contains(.deaf))
        #expect(environment.selectableProfiles.contains(.blind))
    }

    @MainActor
    @Test
    func namesUndeliverableProfilesRatherThanHidingThem() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore())
        // Doctrine 4: a profile that simply never appears teaches the user
        // nothing. It is listed as unavailable, with its missing channel.
        #expect(environment.unavailableProfiles == [.deaf])
        #expect(environment.undeliverableChannels(for: .deaf) == [.caption])
        #expect(environment.undeliverableChannels(for: .deafBlind).isEmpty)
    }

    @MainActor
    @Test
    func doesNotListTheUsersOwnProfileAsUnavailable() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore(Settings(outputProfile: .deaf)))
        // It stays in the picker with a warning row instead — listing it in
        // both places would state the same gap twice.
        #expect(environment.unavailableProfiles.isEmpty)
        #expect(environment.outputProfileOptions.contains(.deaf))
    }

    @MainActor
    @Test
    func keepsAnUndeliverableStoredProfileInThePickerOptions() {
        let environment = AppEnvironment(settingsStore: InMemorySettingsStore(Settings(outputProfile: .deaf)))
        // Dropping it would render the picker blank, which reads as "unset"
        // when the truth is "unsupported".
        #expect(environment.outputProfileOptions.contains(.deaf))
        #expect(environment.undeliverableChannels == [.caption])
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
