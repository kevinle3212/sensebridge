import Foundation
import SenseBridgeCore

/// Direction, proximity, and the end-of-session summary.
///
/// A same-type extension in its own file for SwiftLint's `file_length` and
/// `type_body_length` gates, like `AmbientAwarenessSession+Support.swift` beside
/// it. `deliver`, `alertCount`, `startedAt`, `lastAnnouncedBand`, and
/// `pulseTask` are internal on the class specifically so this file can reach
/// them.
///
/// ## What direction is allowed to claim
///
/// A side is named only when `AwarenessDepthReading.namedZone` allows it, which
/// takes three things: one zone clearly nearer than the others, a measured
/// centre to be "clearly nearer" *than*, and agreement between that zone's
/// distance and the distance the sentence is about. When no side qualifies the
/// sentence is exactly the one this app has always spoken, unqualified.
/// Direction is a detail added to a sentence, never a second decision about
/// whether to speak.
extension AmbientAwarenessSession {
    /// Speaks the awareness alert or clear cue, but only on a real transition —
    /// and keeps the haptic pulse in step with how near the reading is.
    func report(
        _ transition: AwarenessTransition,
        reading: AwarenessDepthReading,
        to environment: AppEnvironment
    ) async {
        switch transition {
        case .becameAlerting:
            alertCount += 1
            await speakAlert(reading: reading, to: environment)
        case .becameClear:
            stopProximityPulse()
            lastAnnouncedBand = nil
            // The first honest emitter of `.awarenessClear` — see its doc
            // comment in `RenderTarget.swift`. It is honest here and only here
            // because a transition is a change the app observed, rather than
            // an absence inferred from one sample.
            await deliver(
                phrasing.nearestMeasurementMovedAway(locale: locale),
                signal: .awarenessClear,
                isUrgent: true,
                to: environment
            )
        case .unchanged:
            await reportIfNearer(reading: reading, to: environment)
        }
    }

    /// The alerting sentence, qualified with a side when one is warranted.
    private func speakAlert(reading: AwarenessDepthReading, to environment: AppEnvironment) async {
        guard let meters = reading.overallMeters else { return }
        let distance = Self.formattedDistance(meters: meters, locale: locale)
        // Two different subjects, not one wrapped in the other: the unqualified
        // phrase says "ahead", so qualifying *it* with a side would put two
        // directions in one sentence. See `Phrasing.somethingAway(atDistance:)`.
        let subject = if let zone = reading.namedZone {
            phrasing.subject(
                phrasing.somethingAway(atDistance: distance, locale: locale), in: zone, locale: locale
            )
        } else {
            phrasing.somethingAhead(atDistance: distance, locale: locale)
        }
        // `.medium`, not `.high`. The reading is a percentile of a
        // confidence-filtered region measured through an uncalibrated chest
        // mount; "it looks like" is what that earns, and "likely" is not.
        let text = phrasing.describe(subject: subject, certainty: .medium, locale: locale)
        lastAnnouncedBand = ProximityBand.band(forMeters: meters)
        startProximityPulse(environment: environment)
        await deliver(text, signal: .awarenessAlert, isUrgent: true, to: environment)
    }

    /// Says the new distance when an already-alerting measurement crosses into a
    /// nearer band.
    ///
    /// Without this, a listener walking toward a wall hears one sentence at
    /// three metres and nothing after it, which is indistinguishable from the
    /// session having stopped. Bounded to one sentence per band rather than per
    /// tick, so approaching something does not produce a stream of speech.
    private func reportIfNearer(reading: AwarenessDepthReading, to environment: AppEnvironment) async {
        guard let meters = reading.overallMeters, let previous = lastAnnouncedBand else { return }
        let band = ProximityBand.band(forMeters: meters)
        guard band < previous else {
            // Receding is not worth a sentence, but the pulse still has to
            // follow it down rather than staying at the nearer cadence.
            trackBand(forMeters: meters, environment: environment)
            return
        }
        lastAnnouncedBand = band
        startProximityPulse(environment: environment)
        await deliver(
            phrasing.measurementCameNearer(
                toDistance: Self.formattedDistance(meters: meters, locale: locale), locale: locale
            ),
            signal: .awarenessAlert,
            isUrgent: true,
            to: environment
        )
    }

    // MARK: - Haptics

    /// Repeats the awareness cue at the cadence of the current band.
    ///
    /// The whole point is the channel prose cannot reach: a Deaf-blind user, or
    /// anyone with headphones out, receives `OutputSignal` alone, and one buzz
    /// says "something is near" whether it is at arm's length or across the
    /// room. This varies the *rate* of the existing cue — it adds no new
    /// pattern to learn. See `ProximityBand`.
    func startProximityPulse(environment: AppEnvironment) {
        stopProximityPulse()
        guard environment.settings.awarenessProximityHapticsEnabled else { return }
        guard lastAnnouncedBand?.repeatInterval != nil else { return }
        pulseTask = Task { [weak self] in
            while !Task.isCancelled {
                // Re-read every iteration rather than captured once. A pulse
                // that latched the band it started at kept buzzing at the
                // "within reach" rate long after the measurement had receded —
                // a vibration carries no hedge, so that is the app asserting
                // arm's-length proximity it no longer measures.
                guard let self, status == .running, let interval = lastAnnouncedBand?.repeatInterval else { return }
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, status == .running else { return }
                await environment.haptics.render(OutputMessage(text: "", signal: .awarenessAlert))
            }
        }
    }

    /// Re-bands an ongoing alert, in either direction, without speaking.
    ///
    /// `reportIfNearer` only ever moves the band nearer, because only that is
    /// worth a sentence. The pulse has to follow the measurement *both* ways or
    /// it keeps claiming a proximity that has passed.
    func trackBand(forMeters meters: Double, environment: AppEnvironment) {
        guard lastAnnouncedBand != nil else { return }
        let band = ProximityBand.band(forMeters: meters)
        guard band != lastAnnouncedBand else { return }
        lastAnnouncedBand = band
        startProximityPulse(environment: environment)
    }

    /// Ends the pulse because the frame carried no measurement at all.
    ///
    /// "Could not measure" is not "nothing is there" — but it is emphatically
    /// not grounds to keep buzzing either. A user standing near a wall who turns
    /// to face glass or a dark matte surface loses the return entirely; the
    /// screen honestly says "not measured" while the phone, left alone, would go
    /// on pulsing "within reach" forever from a reading that no longer exists.
    func stopPulseForUnmeasuredFrame() {
        guard pulseTask != nil else { return }
        stopProximityPulse()
        lastAnnouncedBand = nil
    }

    /// Ends the repeating cue.
    func stopProximityPulse() {
        pulseTask?.cancel()
        pulseTask = nil
    }

    // MARK: - On-screen mirror

    /// The three zones and what each last measured, in words.
    ///
    /// Every unmeasured zone is named as unmeasured rather than omitted. An
    /// absent row would read as "nothing on that side", which is the one claim
    /// this app never makes — see docs/SAFETY-FRAMING.md.
    ///
    /// - Parameter locale: The user's chosen language, not the process locale.
    func zoneSummary(locale: Locale) -> String {
        let zones = lastReading.zones
        return AwarenessZone.allCases.map { zone -> String in
            let name = Self.zoneName(zone)
            guard let meters = zones.distance(in: zone) else {
                return String(
                    localized: "\(name): not measured",
                    comment: "One zone of the awareness reading that produced no measurement."
                )
            }
            let distance = Self.formattedDistance(meters: meters, locale: locale)
            return String(
                localized: "\(name): about \(distance)",
                comment: "One zone of the awareness reading, with its measured distance."
            )
        }
        .joined(separator: " · ")
    }

    /// The user-facing name of a zone, in their own frame of reference — not the
    /// camera's, and not the buffer's.
    static func zoneName(_ zone: AwarenessZone) -> String {
        switch zone {
        case .leading: String(localized: "Left")
        case .center: String(localized: "Ahead")
        case .trailing: String(localized: "Right")
        }
    }

    // MARK: - Summary

    /// What the session did, for the user to hear as it ends.
    ///
    /// Deliberately a statement about this app — alerts raised, minutes run —
    /// and not about the world. "You passed four obstacles" would be a claim
    /// built from readings that were never verified, which
    /// `audits/AGENT-GUIDE.md` rates Critical.
    func sessionSummaryText() -> String {
        let seconds = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        let formatter = DateComponentsFormatter()
        formatter.calendar?.locale = locale
        formatter.allowedUnits = seconds < 60 ? [.second] : [.minute]
        formatter.unitsStyle = .full
        let duration = formatter.string(from: seconds) ?? "\(Int(seconds))"
        return phrasing.sessionSummary(alerts: alertCount, duration: duration, locale: locale)
    }
}
