import Foundation
import Testing
@testable import SenseBridgeCore

/// Regression coverage for the sight→sound→text fusion in
/// `LabelListSceneComposer.compose(from:)` — the local composer that folds
/// every perception stream into one hedged description. Modality separation is
/// doctrine (docs/SAFETY-FRAMING.md): a heard alarm must never be spoken with
/// a sight verb over audio evidence, so these tests pin each stream's verb,
/// not just the presence of its labels.
struct SoundTextSceneFusionTests {
    @Test
    func fusesSightSoundAndTextIntoOneOrderedDescription() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "a fire alarm", confidence: 0.62), capturedAt: .now),
            PerceptionRecord(kind: .recognizedText("EXIT"), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == """
        it looks like there's likely a chair. it sounds like there's a fire alarm. \
        it looks like there's text that reads EXIT.
        """)
    }

    /// Same confidence ladder as objects, different verb — the whole point of
    /// separate sound templates.
    @Test(arguments: [
        (confidence: 0.1, expected: "there might be the sound of speech."),
        (confidence: 0.62, expected: "it sounds like there's speech."),
        (confidence: 0.95, expected: "it sounds like there's likely speech.")
    ])
    func soundSentenceCarriesTheSoundHedgeForItsCertainty(confidence: Double, expected: String) async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let description = try await composer.compose(
            from: [PerceptionRecord(kind: .detectedSound(label: "speech", confidence: confidence), capturedAt: .now)]
        )

        #expect(description == expected)
        #expect(!description.hasPrefix("it looks like")) // never a sight verb over audio evidence
    }

    @Test
    func duplicateSoundLabelsCollapseAcrossConfidenceBuckets() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .detectedSound(label: "a fire alarm", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "a fire alarm", confidence: 0.3), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it sounds like there's likely a fire alarm.")
    }

    /// The same noun in two modalities is spoken twice — deliberately. "A fan"
    /// seen and "a fan" heard are two pieces of evidence, and collapsing them
    /// would erase the modality distinction the hedges carry.
    @Test
    func sameLabelInBothModalitiesKeepsEachModalitysOwnVerb() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .detectedObject(label: "a fan", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "a fan", confidence: 0.9), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it looks like there's likely a fan. it sounds like there's likely a fan.")
    }

    @Test
    func recognizedTextQuotesOnlyTheFirstLine() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let description = try await composer.compose(
            from: [PerceptionRecord(kind: .recognizedText("EXIT\nFLOOR 3"), capturedAt: .now)]
        )

        #expect(description == "it looks like there's text that reads EXIT.")
    }

    @Test
    func surroundingWhitespaceIsTrimmedFromTheQuote() {
        #expect(LabelListSceneComposer.displayQuote(from: "  EXIT SIGN  ") == "EXIT SIGN")
    }

    /// Hard cap so even a garbage recognition stays a momentary interruption
    /// instead of a recital.
    @Test
    func longRecognizedTextIsHardCappedWithAnEllipsis() {
        let longLine = String(repeating: "sign ", count: 30)
        let quote = LabelListSceneComposer.displayQuote(from: longLine)

        #expect(quote.count == Phrasing.maximumRecognizedTextQuoteLength + 1) // + ellipsis character
        #expect(quote.hasSuffix("…"))
    }

    /// A blank recognition has nothing quotable — speaking an empty "text that
    /// reads ." would be worse than saying nothing about text.
    @Test
    func blankRecognizedTextYieldsNoTextSentence() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .recognizedText("   \n  "), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it looks like there's likely a chair.")
    }

    /// Depth belongs to AwarenessEngine's narration, never the scene list.
    @Test
    func depthReadingsStayOutOfSceneComposition() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .depthReading(meters: 1.2), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it looks like there's likely a chair.")
        let lowered = description.lowercased()
        #expect(!lowered.contains("meter") && !lowered.contains("metre"))
    }

    @Test
    func depthOnlyRecordsStillFallBackToNothingRecognized() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let description = try await composer.compose(
            from: [PerceptionRecord(kind: .depthReading(meters: 1.2), capturedAt: .now)]
        )

        #expect(description == "Couldn't name anything.")
    }

    /// Pinned es form for the two new sentence families — mirrors
    /// `SceneComposerTests`' doctrine-pinned baseline.
    @Test
    func fusedSpanishOutputUsesReviewedTemplates() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "es"))
        let records = [
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "a fire alarm", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .recognizedText("SALIDA"), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == """
        parece que probablemente hay a chair. parece que probablemente se escuche a fire alarm. \
        parece que hay texto que dice SALIDA.
        """)
    }

    @Test(arguments: [
        (localeIdentifier: "es", expected: "puede que se escuche speech."),
        (localeIdentifier: "vi", expected: "có thể nghe thấy speech.")
    ])
    func lowSoundHedgeResolvesInBothLocales(localeIdentifier: String, expected: String) async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: localeIdentifier))
        let description = try await composer.compose(
            from: [PerceptionRecord(kind: .detectedSound(label: "speech", confidence: 0.1), capturedAt: .now)]
        )

        #expect(description == expected)
    }
}
