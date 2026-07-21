import SwiftUI

/// The single main screen. Blind users navigate by VoiceOver, not visual
/// layout, so this stays a flat list of clearly labeled mode buttons rather
/// than a deeply nested or gesture-driven layout — see
/// docs/ARCHITECTURE.md "Navigation".
struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Read") { ReadingView() }
                    .accessibilityLabel("Read document")
                    .accessibilityHint("Captures a photo of text and reads it aloud.")
                NavigationLink("Identify") { LabelingView() }
                    .accessibilityLabel("Identify object")
                    .accessibilityHint("Captures a photo and describes what's in it.")
                NavigationLink("Describe") { SceneDescriptionView() }
                    .accessibilityLabel("Describe scene")
                    .accessibilityHint("Composes a hedged description of what the camera sees.")
                NavigationLink("Awareness") { ObstacleAwarenessView() }
                    .accessibilityLabel("Obstacle awareness")
                    .accessibilityHint("Gives cautious alerts about what may be nearby. Not a safety device.")
                NavigationLink("Sounds") { SoundAlertsView() }
                    .accessibilityLabel("Sound alerts")
                    .accessibilityHint("Announces recognized sounds nearby.")
                NavigationLink("Settings") { SettingsView() }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens display language settings.")
            }
            .navigationTitle("SenseBridge")
        }
    }
}

#Preview {
    HomeView()
}
