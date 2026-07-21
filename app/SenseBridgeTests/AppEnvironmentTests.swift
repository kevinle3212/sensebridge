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
}

private final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private var stored: Settings = .init()
    func load() -> Settings {
        stored
    }

    func save(_ settings: Settings) {
        stored = settings
    }
}
