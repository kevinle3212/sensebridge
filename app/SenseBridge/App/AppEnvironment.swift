import SenseBridgeCore
import SwiftUI

/// Root dependency container, injected once at app launch — see
/// docs/ARCHITECTURE.md "State management". Deliberately small: app state
/// is mostly transient perception data plus this settings object.
@MainActor
@Observable
final class AppEnvironment {
    /// Persists `settings` across launches; injectable so tests/previews can
    /// supply an in-memory store.
    let settingsStore: SettingsStore
    /// The user's current settings; mutating this and calling `save()`
    /// persists the change.
    var settings: Settings

    /// Loads settings from `settingsStore`, resetting to defaults first when
    /// launched under `-uiTestReset`.
    init(settingsStore: SettingsStore = UserDefaultsSettingsStore()) {
        self.settingsStore = settingsStore
        // UI tests launch with `-uiTestReset` to start from a known
        // (`.system`) state instead of whatever a previous test run
        // persisted — never set outside a test target.
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            settingsStore.save(Settings())
        }
        settings = settingsStore.load()
    }

    /// Persists the current `settings` to `settingsStore`.
    func save() {
        settingsStore.save(settings)
    }
}
