import CoreGraphics
import Foundation

/// Turns a stream of per-tick detections into a stable outline list.
///
/// Each awareness tick re-runs saliency and classification from scratch, and
/// per-frame noise — a missed proposal, a label that lands at 0.69 this pass —
/// would otherwise pop outlines and nouns in and out every few seconds. That
/// flicker is the single biggest reason live detection reads as worse than its
/// per-frame accuracy. The stabilizer keeps per-label state across ticks: seen
/// in `confirmationTicks` consecutive ticks to appear; dropped after
/// `persistenceTicks` missed ticks.
///
/// A thrown pass is not an empty scene: the session feeds a failed call here
/// with `malfunction: true`, which holds the previous set untouched instead of
/// counting the failure as a frame where nothing was there.
public struct DetectionStabilizer: Sendable {
    /// Sightings needed before a label is shown at all.
    public let confirmationTicks: Int
    /// Missed ticks tolerated before an entry is dropped outright.
    public let persistenceTicks: Int

    private struct Entry {
        var streak = 0
        var missesSinceSighting = 0
        var bestConfidence: Double
        var latestBox: CGRect = .null
        var confirmed = false
    }

    private var entries: [String: Entry] = [:]

    /// Creates a stabilizer. Defaults suit the ambient session's few-second
    /// tick: two sightings to confirm, three missed ticks to forget — both are
    /// open to tuning against device behavior, nothing here is doctrine.
    public init(confirmationTicks: Int = 2, persistenceTicks: Int = 3) {
        self.confirmationTicks = confirmationTicks
        self.persistenceTicks = persistenceTicks
    }

    /// Folds one tick's raw detections into the stable list.
    ///
    /// A `malfunction` pass changes nothing — no tick counted, no miss
    /// recorded, previous output returned as-is. Otherwise every sighting
    /// advances its label's streak, clears its misses, refreshes its box to
    /// this tick's, and raises confidence to the max seen so far. A label
    /// whose streak reaches `confirmationTicks` becomes visible, and stays
    /// visible through later single-tick blips: a missed tick resets the
    /// streak but not the confirmed flag. Every known label absent this tick
    /// accrues one miss and loses its streak; past `persistenceTicks` misses
    /// it is dropped entirely, so a genuinely vacated scene still empties
    /// within `persistenceTicks + 1` ticks.
    public mutating func update(
        _ detections: [DetectedObject],
        malfunction: Bool = false,
        limit: Int = 5
    ) -> [DetectedObject] {
        guard !malfunction else { return currentOutput(limit: limit) }

        var seenThisTick = Set<String>()
        for object in detections {
            seenThisTick.insert(object.label)
            var entry = entries[object.label] ?? Entry(bestConfidence: object.confidence)
            entry.streak += 1
            entry.missesSinceSighting = 0
            entry.latestBox = object.boundingBox
            entry.bestConfidence = max(entry.bestConfidence, object.confidence)
            if !entry.confirmed, entry.streak >= confirmationTicks {
                entry.confirmed = true
            }
            entries[object.label] = entry
        }

        for label in entries.keys where !seenThisTick.contains(label) {
            guard var entry = entries[label] else { continue }
            entry.missesSinceSighting += 1
            entry.streak = 0
            if entry.missesSinceSighting > persistenceTicks {
                entries.removeValue(forKey: label)
            } else {
                entries[label] = entry
            }
        }

        return currentOutput(limit: limit)
    }

    /// Confirmed entries as `DetectedObject` values — the dictionary is keyed
    /// by label, so this is where key and entry are joined for output.
    private func currentOutput(limit: Int) -> [DetectedObject] {
        entries
            .compactMap { label, entry -> DetectedObject? in
                guard entry.confirmed else { return nil }
                return DetectedObject(
                    label: label,
                    confidence: entry.bestConfidence,
                    boundingBox: entry.latestBox
                )
            }
            .sorted { $0.confidence > $1.confidence }
            .prefix(limit)
            .map(\.self)
    }
}
