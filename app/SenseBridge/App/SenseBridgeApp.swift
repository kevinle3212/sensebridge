import SwiftUI

/// App entry point. Builds the single `AppEnvironment` used for the whole
/// run and injects it into the view hierarchy, along with the user's chosen
/// display language — see docs/ARCHITECTURE.md "State management".
@main
struct SenseBridgeApp: App {
    /// The app's single dependency container; owned here so it survives for
    /// the life of the process and is injected once into the view hierarchy.
    @State private var environment: AppEnvironment = .init()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(environment)
                .environment(\.locale, environment.settings.language.locale ?? .autoupdatingCurrent)
        }
    }
}
