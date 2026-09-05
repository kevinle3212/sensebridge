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
            // `safeAreaInset` comes *before* the `.environment` modifiers, not
            // after. Its content is attached as a sibling of the view it is
            // applied to, not a descendant, so an `.environment` applied first
            // never reaches it — `CaptionOverlay` read `AppEnvironment` out of
            // an environment it was not in and trapped on launch.
            RootView()
                .safeAreaInset(edge: .bottom) {
                    CaptionOverlay()
                }
            #if DEBUG
                .safeAreaInset(edge: .bottom) {
                    // Stacks beneath the caption inset, never over content —
                    // see `DevWatermarkFooter` for why it is dev-only.
                    DevWatermarkFooter()
                }
            #endif
                .environment(environment)
                .environment(\.locale, environment.settings.language.locale ?? .autoupdatingCurrent)
        }
    }
}

/// Branches between the first-run walkthrough and the home list. A separate
/// view (rather than an `if` inline in `SenseBridgeApp.body`) so it can read
/// `environment.settings.hasCompletedOnboarding` reactively — `@State` in
/// the App type itself doesn't re-render `body` when a nested `@Observable`
/// property changes.
private struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.settings.hasCompletedOnboarding {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}
