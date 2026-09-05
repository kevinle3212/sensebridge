import Foundation
import Testing
@testable import SenseBridgeCore

/// Property tests over randomized and adversarial recognized text.
///
/// OCR output is attacker-adjacent input in the only sense that matters here: it
/// is arbitrary bytes off a page nobody vetted, and it flows straight into
/// segmentation, playback, and the speech synthesiser. A page carrying a format
/// specifier, a right-to-left override, or a hundred combining marks on one
/// character must not be able to crash the app, silence playback, or strip the
/// hedge off a spoken claim.
struct ReadingTextFuzzTests {
    /// A deterministic PRNG so a failure reproduces from its seed — see
    /// `DepthFuzzTests` for the same reasoning.
    private struct Seeded: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed &* 6_364_136_223_846_793_005 &+ 1
        }

        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    /// Fragments a real page has produced, plus the ones that break naive text
    /// handling: format specifiers, bidirectional overrides, combining marks,
    /// zero-width joiners, and lone surrogate-adjacent scalars.
    private static let hostileFragments = [
        "%@", "%1$@", "%n", "%s%s%s", "%%",
        "\u{202E}gnidaeR", "\u{200B}", "\u{200D}", "\u{FEFF}",
        "e" + String(repeating: "\u{0301}", count: 60),
        "👋🏽", "🏳️‍🌈", "nghiêng", "الصفحة", "日本語のページ",
        "\0", "\t\t", "\r\n", "   ", "",
        "Take 3.5 mg.", "Dr. Chen", "Gate 12.", "A.B.C.",
        String(repeating: "a", count: 600), String(repeating: "word ", count: 200)
    ]

    /// One value from `items`, chosen by the seeded generator — `randomElement`
    /// returns an optional this file has no sensible answer for.
    private func pick<Element>(_ items: [Element], using generator: inout Seeded) -> Element {
        items[Int.random(in: 0 ..< items.count, using: &generator)]
    }

    /// A random page built out of hostile fragments and random scalars.
    private func hostilePage(using generator: inout Seeded) -> String {
        let pieces = Int.random(in: 0 ... 12, using: &generator)
        return (0 ..< pieces).map { _ -> String in
            if Bool.random(using: &generator) {
                return pick(Self.hostileFragments, using: &generator)
            }
            let scalar = UnicodeScalar(UInt32.random(in: 0x20 ... 0x2FFF, using: &generator)) ?? " "
            return String(String.UnicodeScalarView([scalar]))
        }.joined(separator: Bool.random(using: &generator) ? " " : "\n")
    }

    @Test
    func segmentationNeverProducesAnEmptyOrOversizedSegment() {
        // An empty segment speaks as silence, which a listener cannot tell from
        // the app having stopped. An oversized one is the whole-page blob this
        // type exists to replace.
        var generator = Seeded(seed: 0x5EED)

        for _ in 0 ..< 3000 {
            let segments = TextSegmenter.segments(from: hostilePage(using: &generator))

            #expect(segments.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            #expect(segments.allSatisfy { $0.count <= TextSegmenter.maximumSegmentLength })
        }
    }

    @Test
    func segmentationKeepsEveryNonWhitespaceCharacterOfThePage() {
        // Playback reads the segments and nothing else, so a character dropped
        // here is a word the listener never hears — silently.
        var generator = Seeded(seed: 0x0FF1CE)

        for _ in 0 ..< 2000 {
            let page = hostilePage(using: &generator)
            let expected = page.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            let actual = TextSegmenter.segments(from: page)
                .joined()
                .unicodeScalars
                .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }

            #expect(Array(actual) == Array(expected))
        }
    }

    @Test
    func everySegmentIsWholeCharactersThatRoundTripThroughUnicode() {
        // Splitting inside a grapheme cluster produces two strings that render
        // as garbage and speak as nothing.
        var generator = Seeded(seed: 0xB0A7)

        for _ in 0 ..< 2000 {
            let page = hostilePage(using: &generator)
            let segments = TextSegmenter.segments(from: page)

            for segment in segments {
                #expect(String(segment.unicodeScalars) == segment)
            }
            // Splitting one cluster into two makes two Characters out of one, so
            // the total can only ever fall (separators dropped), never rise.
            #expect(segments.reduce(into: 0) { $0 += $1.count } <= page.count)
        }
    }

    @Test
    func playbackWalksEverySegmentExactlyOnceWhateverThePageContained() {
        var generator = Seeded(seed: 0xCAFE)

        for _ in 0 ..< 1000 {
            let segments = TextSegmenter.segments(from: hostilePage(using: &generator))
            var playback = ReadingPlayback(segments: segments)

            var heard = [String]()
            if let first = playback.current {
                heard.append(first)
            }
            while let next = playback.advance() {
                heard.append(next)
            }

            #expect(heard == segments)
            #expect(playback.isFinished == !segments.isEmpty)
        }
    }

    @Test
    func playbackSurvivesAnyOrderOfControlsWithoutTrappingOrGoingSilent() {
        // The Read screen's controls are reachable in any order, including from
        // VoiceOver gestures that fire faster than speech finishes.
        var generator = Seeded(seed: 0x7A57)

        for _ in 0 ..< 1000 {
            let segments = TextSegmenter.segments(from: hostilePage(using: &generator))
            var playback = ReadingPlayback(segments: segments)

            for _ in 0 ..< 40 {
                switch Int.random(in: 0 ... 3, using: &generator) {
                case 0: playback.advance()
                case 1: playback.retreat()
                case 2: playback.restart()
                default: playback.move(to: Int.random(in: -5 ... 50, using: &generator))
                }
                if let position = playback.position {
                    #expect((1 ... playback.count).contains(position))
                    #expect(playback.current?.isEmpty == false)
                }
            }
        }
    }

    @Test
    func aPageCarryingAFormatSpecifierNeverReachesAFormatString() {
        // The one genuine injection path in a screen full of user-supplied text:
        // recognized text that reads "%@" must be spoken, not interpreted.
        let phrasing = Phrasing()

        for hostile in ["%@", "%1$@", "%n", "%s", "%%"] {
            let qualified = phrasing.subject(hostile, in: .leading, locale: Locale(identifier: "en"))

            #expect(qualified.contains(hostile))
            #expect(qualified.hasSuffix("on your left"))
        }
    }

    @Test
    func aZoneQualifiedSubjectStaysHedgedInEveryLanguage() {
        // The qualifier is applied to the subject *before* hedging, so a bug
        // that hedged first would produce a confident directional claim — the
        // exact archetype audits/AGENT-GUIDE.md rates Critical.
        var generator = Seeded(seed: 0x11FE)

        for identifier in ["en", "es", "vi"] {
            let locale = Locale(identifier: identifier)
            let fragments = Phrasing.hedgeFragments(locale: locale)
            for _ in 0 ..< 200 {
                let subject = pick(Self.hostileFragments, using: &generator)
                let zone = pick(AwarenessZone.allCases, using: &generator)
                let certainty = pick(Certainty.allCases, using: &generator)

                let phrase = Phrasing().describe(
                    subject: Phrasing().subject(subject, in: zone, locale: locale),
                    certainty: certainty,
                    locale: locale
                )

                #expect(
                    fragments.contains { phrase.hasPrefix($0) },
                    "\"\(phrase)\" must start with a known hedge fragment"
                )
            }
        }
    }

    @Test
    func aSummaryNeverExceedsItsLimitOrEndsMidGraphemeCluster() {
        var generator = Seeded(seed: 0x5E7)

        for _ in 0 ..< 2000 {
            let document = ReadingDocument(pages: [hostilePage(using: &generator)])
            let limit = Int.random(in: 1 ... 80, using: &generator)

            let summary = document.summary(limit: limit)

            // The ellipsis is added after clipping, so the bound is limit + 1.
            #expect(summary.count <= limit + 1)
            #expect(String(summary.unicodeScalars) == summary)
        }
    }

    @Test
    func framingGuidanceIsAlwaysACompleteSentenceOrNothingAtAll() {
        // Live reading evaluates several frames a second: a guidance string that
        // came back as a bare fragment would be spoken as one.
        var generator = Seeded(seed: 0x6412)
        let phrasing = Phrasing()

        for identifier in ["en", "es", "vi"] {
            let locale = Locale(identifier: identifier)
            for _ in 0 ..< 500 {
                var edges = Set<ReadingFraming.Edge>()
                for edge in ReadingFraming.Edge.allCases where Bool.random(using: &generator) {
                    edges.insert(edge)
                }
                let nonEdgeCases: [ReadingFraming.Guidance] = [.noTextRecognized, .textLooksSmall, .wellFramed]
                let guidance: ReadingFraming.Guidance = edges.isEmpty
                    ? pick(nonEdgeCases, using: &generator)
                    : .textRunsPastEdges(edges)

                let spoken = phrasing.framingGuidance(for: guidance, locale: locale)

                if guidance == .wellFramed {
                    #expect(spoken == nil)
                } else {
                    let sentence = try? #require(spoken)
                    #expect(sentence?.isEmpty == false)
                    #expect(sentence?.contains("%") == false)
                }
            }
        }
    }
}
