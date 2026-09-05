import Foundation

/// How much a composed description says. Scales three existing numbers — how
/// many objects are named, and how many words the composed noun phrase may
/// use — and nothing else.
///
/// **It never scales certainty.** Every level runs the same detector precision
/// floor, the same `Phrasing` hedge templates, and the same
/// `Phrasing.certainty(forConfidence:)` buckets. A more detailed description is
/// a longer list of things the app is equally unsure about, never a more
/// confident claim about any one of them — see docs/SAFETY-FRAMING.md.
public enum SpokenDetail: String, Sendable, Codable, CaseIterable {
    case concise, standard, detailed

    /// How many objects one description may name.
    ///
    /// Raises the *count* only. `ObjectClassificationService.minimumPrecision`
    /// and `minimumRegionArea` are untouched at every level: naming more things
    /// is honest, naming them from weaker evidence is not.
    public var maximumLabels: Int {
        switch self {
        case .concise: 2
        case .standard: 3
        case .detailed: 5
        }
    }

    /// The word ceiling for the composed noun phrase, scaled by how many labels
    /// the composer was actually given.
    ///
    /// Input-scaled rather than a flat constant, because a flat 20-word budget
    /// handed two labels is 16 words of room to invent an adjective the
    /// classifier never produced. Four words per label plus four for articles
    /// and conjunctions is enough to join what is there and not enough to add
    /// what is not.
    public func maximumPhraseWords(labelCount: Int) -> Int {
        let perLabel = self == .concise ? 3 : 4
        return min(24, max(6, perLabel * max(labelCount, 1) + 4))
    }
}
