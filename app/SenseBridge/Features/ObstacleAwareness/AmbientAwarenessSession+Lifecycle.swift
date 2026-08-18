import Foundation
import SenseBridgeCore
import UIKit

/// App-lifecycle and thermal pacing for hands-free awareness: the two things
/// that change what the session is doing without the user having touched it.
///
/// Both belong together because both have the same failure mode. The session
/// speaks; a change it does not announce reaches the user as silence, and
/// `docs/SAFETY-FRAMING.md` treats silence on this channel as indistinguishable
/// from "nothing to report". So every transition here — stopped, resumed,
/// slowed, back to normal — says so out loud.
///
/// Split from `AmbientAwarenessSession.swift` for the same reason
/// `+Support.swift` was: SwiftLint's `file_length`/`type_body_length` gates.
/// The stored properties this reads are internal rather than `private`
/// specifically so this same-type extension, in a different file, can reach
/// them.
extension AmbientAwarenessSession {
    // MARK: - Thermal pacing

    /// How long to wait before the next depth sample, after checking whether
    /// the device has heated up — and announcing it if the answer changed.
    ///
    /// Read per tick rather than observed via `thermalStateDidChangeNotification`
    /// because the loop already runs on a fixed cadence and
    /// `ProcessInfo.thermalState` is a cheap property read: one more observer
    /// with its own lifetime to unregister buys nothing here.
    func thermalPacedInterval(environment: AppEnvironment) async -> Duration {
        let level = ThermalBackoff.level(for: ProcessInfo.processInfo.thermalState)
        if let notice = ThermalBackoff.notice(changingFrom: thermalLevel, to: level, locale: locale) {
            thermalLevel = level
            await announce(notice, to: environment)
        }
        return Self.sampleInterval * ThermalBackoff.intervalMultiplier(for: level)
    }

    /// The narration cadence, stretched by the same thermal factor as sampling.
    ///
    /// Composition is the expensive half of the loop — a classifier pass plus
    /// either an on-device model or a network round-trip — so leaving it at
    /// full rate while sampling slowed would back off the cheap work and keep
    /// the costly work, which is the wrong way round.
    func narrationInterval(environment: AppEnvironment) -> TimeInterval {
        environment.settings.narrationIntervalSeconds
            * ThermalBackoff.intervalMultiplier(for: thermalLevel)
    }

    // MARK: - App lifecycle

    /// Stops the session when the app is backgrounded, says so, and arms the
    /// resume for when it comes back.
    ///
    /// iOS revokes camera access on backgrounding, so the loop would otherwise
    /// keep running against frames that never arrive — perfectly silent, and
    /// indistinguishable from a quiet room to someone who cannot see the
    /// screen. The `audio` background mode exists in this target so this one
    /// announcement is audible; nothing else in the app plays in the
    /// background.
    func observeLifecycle(environment: AppEnvironment) {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, status == .running else { return }
                stop()
                // Set *after* `stop()`, which clears it: stopping is how this
                // session ends for every other reason too, and only this path
                // has earned a resume.
                isAwaitingForegroundResume = true
                observeReactivation(environment: environment)
                await announce(
                    phrasing.awarenessStoppedOffScreen(locale: locale),
                    to: environment,
                    signal: .error
                )
            }
        }
    }

    /// Restarts the session the next time the app becomes active, once.
    ///
    /// `didBecomeActive` rather than `willEnterForeground`: ARKit will not
    /// start a world-tracking session for an app that is not yet active, so
    /// resuming on the earlier edge would fail on exactly the transition it
    /// exists to handle.
    ///
    /// A failed resume is announced too. Someone with the phone on their chest
    /// who was told "it will start again when you come back" and then hears
    /// nothing has no way to discover that it didn't.
    private func observeReactivation(environment: AppEnvironment) {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, isAwaitingForegroundResume else { return }
                isAwaitingForegroundResume = false
                removeForegroundObserver()
                await start(environment: environment)
                switch status {
                case .running:
                    await announce(phrasing.awarenessRunningAgain(locale: locale), to: environment)
                case let .unavailable(reason):
                    await announce(reason, to: environment, signal: .error)
                case .idle:
                    break
                }
            }
        }
    }

    /// Drops the reactivation observer. Called from `stop()` as well as after a
    /// resume fires, so a session the user ends by hand — or by leaving the
    /// screen — never resurrects itself later.
    func removeForegroundObserver() {
        guard let foregroundObserver else { return }
        NotificationCenter.default.removeObserver(foregroundObserver)
        self.foregroundObserver = nil
    }

    /// Speaks a lifecycle notice and mirrors it on screen.
    ///
    /// These are statements about the app, not about the world, so they carry
    /// no hedge — there is nothing being claimed about what is or is not there.
    private func announce(
        _ text: String,
        to environment: AppEnvironment,
        signal: OutputSignal = .resultReady
    ) async {
        lastNarration = text
        await environment.output.render(OutputMessage(text: text, signal: signal))
    }
}
