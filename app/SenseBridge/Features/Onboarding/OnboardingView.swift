import SenseBridgeCore
import SwiftUI
import UIKit

/// First-run walkthrough: what SenseBridge does, camera/microphone
/// permission priming, and the crash-reporting opt-in — shown once, gated by
/// `Settings.hasCompletedOnboarding`. Flat step navigation, no swipe-only
/// gestures, so a VoiceOver user can move through it the same way they move
/// through every other screen — see docs/ARCHITECTURE.md "Navigation".
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var step: Step = .welcome

    private enum Step: Int, CaseIterable {
        case welcome, permissions, diagnostics, done
    }

    var body: some View {
        // `diagnosticsStep` is its own `Form` (already `List`-backed and
        // self-scrolling within its `.frame(maxHeight:)`) — nesting a
        // second `List`-backed container inside an outer `ScrollView`
        // collapses its layout, so only the two plain-text steps that can
        // actually clip at large Dynamic Type get wrapped, and the nav
        // buttons stay outside any scroll container so they're always
        // reachable without swiping past them.
        VStack(spacing: 24) {
            switch step {
            case .welcome: ScrollView { welcomeStep }
            case .permissions: ScrollView { permissionsStep }
            case .diagnostics: diagnosticsStep
            case .done: EmptyView() // finish() advances past this before a frame renders it.
            }
            HStack {
                if step != .welcome {
                    Button("Back") { back() }
                        .accessibilityHint("Returns to the previous step.")
                }
                Spacer()
                Button(step == .diagnostics ? "Finish" : "Next") { advance() }
                    .accessibilityHint(
                        step == .diagnostics
                            ? "Completes setup and opens SenseBridge."
                            : "Continues to the next step."
                    )
            }
        }
        .padding()
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to SenseBridge")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("""
            SenseBridge gives you spoken awareness of what's around you — reading text, \
            identifying objects, describing scenes, and recognizing sounds. It runs \
            entirely on your device.
            """)
            // The doctrine-mandated statement — see docs/SAFETY-FRAMING.md
            // "The rule". Stated here, not just on the Awareness screen,
            // because this is the first thing every user reads, and a
            // welcome screen that only disclaims "a guarantee" (as this one
            // used to) leaves the device-category claim unmade.
            Text("""
            SenseBridge is not a mobility or safety device. It does not replace a cane, \
            a guide dog, or orientation-and-mobility training.
            """)
            .font(.callout)
            .fontWeight(.semibold)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera and microphone")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("""
            SenseBridge uses the camera to read text, identify objects, and describe \
            scenes, and the microphone to recognize nearby sounds. What the camera and \
            microphone capture stays on your device. This screen is about to ask the \
            system for that permission — you can also grant it later in Settings.
            """)
        }
        .task {
            await environment.camera.start(applying: environment.settings)
            await environment.camera.stop()
            _ = try? await MicrophoneSensingSource().record(duration: 0.1)
        }
    }

    private var diagnosticsStep: some View {
        @Bindable var environment = environment
        // No fixed `.frame(maxHeight:)` — a hardcoded cap clipped this
        // section's content at larger Dynamic Type sizes (confirmed via a
        // real accessibility-audit "Text clipped" finding). Sized to its
        // content instead, same as `welcomeStep`/`permissionsStep`.
        return Form {
            DiagnosticsSettingsSection(crashReportingEnabled: $environment.settings.crashReportingEnabled)
        }
        .onChange(of: environment.settings.crashReportingEnabled) { _, _ in environment.save() }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
        if step == .done {
            finish()
        } else {
            announceStepChange()
        }
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
        announceStepChange()
    }

    /// A full-screen content swap needs `.screenChanged`, not the
    /// `.layoutChanged` `ReadingView`/`LabelingView`/`SceneDescriptionView`
    /// post for a smaller addition to an otherwise-unchanged screen — see
    /// their own `startCameraIfNeeded()`. Without this, VoiceOver focus
    /// stays on the "Next"/"Back" button that was just tapped and the new
    /// step's heading is never announced. Passing the heading directly as
    /// the argument makes VoiceOver speak it immediately; `diagnosticsStep`
    /// has no standalone heading of its own (its `Form` section header
    /// serves that role), so this falls back to a plain rescan there.
    private func announceStepChange() {
        UIAccessibility.post(notification: .screenChanged, argument: heading(for: step))
    }

    private func heading(for step: Step) -> String? {
        switch step {
        case .welcome: "Welcome to SenseBridge"
        case .permissions: "Camera and microphone"
        case .diagnostics, .done: nil
        }
    }

    private func finish() {
        environment.settings.hasCompletedOnboarding = true
        environment.save()
    }
}

#Preview {
    OnboardingView()
        .environment(AppEnvironment())
}
