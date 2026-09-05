# Descriptive voice + a more comprehensive on-device default Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make spoken output more descriptive and the **default (on-device)**
path more comprehensive — more objects named, fluent grouping instead of
repeated stock sentences, spoken full words instead of abbreviations — and give
the user a detail-level control, without weakening a single hedge, adding a
dependency, sending anything new off the device, or shipping a model.

**Architecture:** No new seams. Everything lands behind the existing
`SensingSource → Perception → SceneComposer → Phrasing → RenderTarget` chain
that `docs/superpowers/plans/2026-08-11-awareness-ai-tiers-plan.md` just
finished wiring. A new `SpokenDetail` value in `Settings` scales three existing
numbers (`ObjectClassificationService.maximumLabels`, the `@Generable` phrase
budget, `ReasoningOutputValidator`'s word ceiling); `LabelListSceneComposer` —
the composer that actually runs when Apple Intelligence is unavailable, i.e.
"the current default one" at its worst — is rewritten to group by certainty
bucket; and the two duplicated identifier→noun-phrase converters are merged
into one testable helper that also expands abbreviations.

**Tech Stack:** Swift 6.2, SwiftUI, `SenseBridgeCore` SwiftPM package,
Foundation (`ListFormatStyle`, `MeasurementFormatter`), Apple Vision,
FoundationModels (`@Generable`), Swift Testing. **No new dependency, no new
network endpoint, no new bundled asset, no model or dataset.**

**Out of scope (already fixed this session):** the abbreviated-unit bug
(`MeasurementFormatter` `.medium` → `.long`) at
`app/SenseBridge/Features/ObstacleAwareness/AmbientAwarenessSession+Support.swift:79-86`
and `app/SenseBridge/App/SettingsSections.swift:131-137`. Do not re-plan it.

## Global Constraints

- **The model still never writes the sentence.** `@Generable` returns a noun
  phrase; `Phrasing` applies the hedge; `Certainty` comes from the *detector's*
  confidence, never the model's fluency. `docs/SAFETY-FRAMING.md` "A language
  model may never write the final sentence" is untouched by every task here.
- **More detail never means more certainty.** No task may raise a certainty
  bucket, remove a hedge, shorten a hedge, or introduce a word the app cannot
  back with a measurement it made.
- **Never lower a precision floor to produce more output.**
  `ObjectClassificationService.minimumPrecision` (0.7) and
  `minimumRegionArea` (0.02) are frozen by this plan. Both are documented in
  that file as accuracy-critical; naming more things less accurately is the
  failure `docs/SAFETY-FRAMING.md` ranks above a crash.
- **The wire contract is unchanged.**
  `[PerceptionRecord].detectedObjectLabelsForNetwork()` still serializes object
  labels only. No task adds a field to it. `SpokenDetail` changes a local word
  ceiling; it is never itself transmitted as user data.
- **No control that delivers nothing** (AGENTS.md doctrine 4, first corollary).
  If detail level is offered, it must actually change output on every backend
  the user can select — see Task 5.
- Every new or changed UI string ships `en`, `es`, and `vi` in the same commit;
  `npm run check:catalog-coverage` is the gate.
- `legal/**` is never touched by this plan. Nothing here changes what leaves
  the device, so no privacy or subprocessor text moves.
- Test locations follow the existing convention:
  `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/<Type>Tests.swift`,
  `app/SenseBridgeTests/`, `app/SenseBridgeUITests/`. Any test touching
  `LocalizedCatalog` must also pass under
  `xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS'` from
  `app/` — `swift test` alone does not compile `.xcstrings`
  (`docs/TESTING.md`).
- **Safety-framing-reviewer sign-off is blocking** (Task 10). Every task below
  touches spoken output.

---

### Task 1: `SpokenPhrase` — one identifier→noun-phrase converter, with abbreviation expansion

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/SpokenPhrase.swift`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/ObjectClassificationService.swift:184-192`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/SoundClassificationRunner.swift:88-92`
- Create: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/SpokenPhraseTests.swift`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ObjectClassificationServiceTests.swift:64-65`

**Interfaces:** Produces `enum SpokenPhrase { static func subject(for identifier: String) -> String }`.
Consumed by both classifier services. `ObjectClassificationService.subjectPhrase(for:)`
and `SoundClassificationRunner.subjectPhrase(for:)` become one-line forwards, so
existing call sites and tests keep compiling.

**Why this is the root-cause shape:** the two services carry byte-identical
copies of the article logic today (`ObjectClassificationService.swift:184-192`,
`SoundClassificationRunner.swift:88-92`), and `SoundClassificationRunner`'s own
doc comment says it "mirrors `ObjectClassificationService.subjectPhrase(for:)`
exactly." Fixing pronunciation in one and not the other is how a sound event
ends up reading differently from an object. One helper, both callers.

- [ ] **Step 1: Write the shared helper**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/SpokenPhrase.swift
import Foundation

/// Turns a bare Vision or Sound Analysis identifier ("coffee_mug", "tv") into
/// the article-first noun phrase `Phrasing.describe(subject:certainty:)`
/// expects ("a coffee mug", "a television").
///
/// One implementation for both classifiers on purpose:
/// `ObjectClassificationService` and `SoundClassificationRunner` each carried a
/// byte-identical copy before this type existed, so a pronunciation fix landed
/// in one and not the other would make a sound event read differently from an
/// object seen in the same room.
///
/// **English-only, and knowingly so.** The identifier vocabularies of both
/// frameworks are English, which `ObjectClassificationService` already
/// documents as a limitation: a Spanish or Vietnamese user hears an English
/// noun inside a translated hedge, because naming the object *wrongly* would be
/// worse than naming it in the wrong language. This type inherits that
/// limitation unchanged — it does not add one.
public enum SpokenPhrase {
    /// Written-abbreviation identifiers whose spoken form is a different,
    /// unambiguous word. Deliberately tiny and hand-verified rather than
    /// generated: an entry that guesses wrong makes the app confidently
    /// mis-name a physical object, which docs/SAFETY-FRAMING.md ranks above a
    /// crash. Extend only with an identifier observed in a real classifier
    /// result — see this plan's "Deferred to Kevin", item 4.
    ///
    /// Not localized: the keys are English identifiers and the values are
    /// English words, per this type's documented English-only scope.
    private static let spokenForms: [String: String] = [
        "tv": "television",
        "tv monitor": "television",
        "cd player": "compact disc player",
        "dvd player": "digital video disc player",
        "atm": "cash machine",
        "suv": "sport utility vehicle",
        "pc": "personal computer",
        "rv": "recreational vehicle"
    ]

    /// Identifiers whose written first letter disagrees with the sound that
    /// starts them. `ObjectClassificationService` documented "a unicycle" as an
    /// accepted wrong answer; the list is short enough to just be right.
    private static let consonantSoundedVowelPrefixes = [
        "uni", "use", "user", "eu", "ewe", "one"
    ]
    private static let vowelSoundedConsonantPrefixes = ["hour", "honest", "honou", "honor"]

    /// The article-first spoken phrase for `identifier`.
    public static func subject(for identifier: String) -> String {
        let words = spokenForms[identifier.replacing("_", with: " ").lowercased()]
            ?? identifier.replacing("_", with: " ")
        guard let first = words.first else { return words }
        let lowered = words.lowercased()
        if vowelSoundedConsonantPrefixes.contains(where: lowered.hasPrefix) {
            return "an \(words)"
        }
        if consonantSoundedVowelPrefixes.contains(where: lowered.hasPrefix) {
            return "a \(words)"
        }
        return "aeiou".contains(first.lowercased()) ? "an \(words)" : "a \(words)"
    }
}
```

- [ ] **Step 2: Forward both existing entry points**

Replace the body of `ObjectClassificationService.subjectPhrase(for:)`
(currently lines 184-192) and `SoundClassificationRunner.subjectPhrase(for:)`
(currently lines 88-92) with `SpokenPhrase.subject(for: identifier)`, keeping
each existing doc comment and adding one line pointing at `SpokenPhrase`.
**Do not delete either wrapper** — `ObjectClassificationServiceTests.swift:64-65`
calls one directly, and both are referenced from doc comments elsewhere.

- [ ] **Step 3: Test**

`SpokenPhraseTests.swift` — assert: `"coffee_mug"` → `"a coffee mug"`,
`"escalator"` → `"an escalator"`, `"tv"` → `"a television"`,
`"cd_player"` → `"a compact disc player"`, `"unicycle"` → `"a unicycle"`,
`"hourglass"` → `"an hourglass"`, `""` → `""` (empty input, no crash),
`"café_table"` → `"a café table"` (unicode passthrough, unchanged).

**Acceptance:**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter SpokenPhraseTests
cd app/Packages/SenseBridgeCore && swift test --filter ObjectClassificationServiceTests
```

Both PASS, and the pre-existing `ObjectClassificationServiceTests` assertions
are unmodified.

- [ ] **Step 4: Commit** — `refactor(perception): merge the two identifier-to-noun-phrase converters and expand spoken abbreviations`

---

### Task 2: `SpokenDetail` in `Settings`

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/SpokenDetail.swift`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/Settings.swift`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/SettingsTests.swift`

**Interfaces:** Produces `SpokenDetail` (`.concise`, `.standard`, `.detailed`)
with `var maximumLabels: Int` and `func maximumPhraseWords(labelCount: Int) -> Int`;
`Settings.spokenDetail: SpokenDetail`, default `.standard`. Consumed by Tasks 3-8.

**The shipped default is `.standard`, and `.standard` is not "today".** Tasks 1
and 3 improve `.standard` output for every user with no opt-in: grouped
sentences, expanded abbreviations, correct articles. What `.standard` does *not*
do is raise the object count or the phrase budget, because that changes how much
the highest-severity surface in the app says, and no machine in this repo can
validate that — only a listen on a real device can. Flipping the default is
Kevin's call, in the morning, after that listen (see "Deferred to Kevin",
item 3).

- [ ] **Step 1: Write the enum**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/SpokenDetail.swift
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
    /// what is not. Caught in this plan's self-review pass (finding R3).
    public func maximumPhraseWords(labelCount: Int) -> Int {
        let perLabel = self == .concise ? 3 : 4
        return min(24, max(6, perLabel * max(labelCount, 1) + 4))
    }
}
```

- [ ] **Step 2: Add the field to `Settings`**

Add `public var spokenDetail: SpokenDetail` after `hasCompletedOnboarding`,
add it to `init(...)` with `spokenDetail: SpokenDetail = .standard`, and add
`spokenDetail` to `CodingKeys`.

In `init(from:)`, follow the **never-fail** pattern `Settings.swift:117-123`
mandates verbatim — decode the raw string, map it, and degrade to `.standard`
on absence or an unrecognized value. Never a throwing decode of a required key;
a single unknown value must not reset speech rate, output profile, and
onboarding state:

```swift
        if let detailRaw = try container.decodeIfPresent(String.self, forKey: .spokenDetail),
           let detail = SpokenDetail(rawValue: detailRaw) {
            spokenDetail = detail
        } else {
            spokenDetail = .standard
        }
```

- [ ] **Step 3: Test**

Extend `SettingsTests.swift`: a settings blob persisted before this field
existed decodes with `.standard` and every other field intact; an unrecognized
`spokenDetail` value ("gigantic") decodes to `.standard` **without** resetting
`speechRate`/`outputProfile`; a round-trip of `.detailed` survives
encode→decode.

**Acceptance:**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter SettingsTests
```

PASS, including the two back-compat cases.

- [ ] **Step 4: Commit** — `feat(core): add a spoken-detail preference`

---

### Task 3: `LabelListSceneComposer` — group by certainty instead of repeating a stock sentence

**Files:**

- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/SceneComposer.swift:16-45`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/SceneComposerTests.swift`

**Interfaces:** `LabelListSceneComposer.init(phrasing:locale:detail:)` gains a
`detail: SpokenDetail = .standard` parameter. `compose(from:)` signature
unchanged.

**Why this is the highest-value task in the plan.** This composer is what runs
whenever `FoundationModelsSceneComposer.isModelAvailable` is `false` — no Apple
Intelligence, Apple Intelligence switched off, model still downloading, or the
model throwing. It is literally "the current default one" at its worst, and
today it emits one full hedged sentence per object:

> "it looks like there's a chair. it looks like there's a table. there might be a lamp."

Grouped by certainty bucket, that becomes:

> "it looks like there's a chair and a table. there might be a lamp."

Same three objects, same three hedges, each object still carried at exactly the
certainty its own detector confidence earned. This is a fluency change, not an
accuracy change — which is precisely why it is safe to ship on by default.

- [ ] **Step 1: Rewrite `compose(from:)`**

```swift
    public func compose(from records: [PerceptionRecord]) async throws -> String {
        // Bucket, don't flatten. An earlier draft joined every label into one
        // list and applied a single certainty to the sentence — which speaks a
        // doubtful detection under a confident detection's hedge. Grouping
        // keeps each object at the certainty its own detector confidence
        // earned. Caught in this plan's self-review pass (finding R7).
        var byCertainty = [Certainty: [String]]()
        for record in records {
            guard case let .detectedObject(label, confidence) = record.kind else { continue }
            byCertainty[Phrasing.certainty(forConfidence: confidence), default: []].append(label)
        }
        guard !byCertainty.isEmpty else { return phrasing.nothingRecognized(locale: locale) }

        // Most-confident bucket first: the thing the app is least unsure about
        // arrives before the channel is interrupted or the user walks on.
        let ordered: [Certainty] = [.high, .medium, .low]
        return ordered.compactMap { certainty -> String? in
            guard let labels = byCertainty[certainty], !labels.isEmpty else { return nil }
            let subject = Array(labels.prefix(detail.maximumLabels))
                .formatted(.list(type: .and).locale(locale))
            return phrasing.describe(subject: subject, certainty: certainty, locale: locale)
        }.joined(separator: " ")
    }
```

`ListFormatStyle` (`.formatted(.list(type: .and).locale(locale))`) is
Foundation, not a dependency, and it is the only thing here that knows Spanish
uses "y"/"e" and Vietnamese uses "và" — hardcoding " and " would put an English
conjunction inside a translated hedge, which is the exact bug Task 13 of the
2026-08-11 plan fixed on the model path.

Keep the existing `// swiftlint:disable:next unneeded_throws_rethrows` comment;
this implementation still never throws.

- [ ] **Step 2: Test**

Extend `SceneComposerTests.swift`:

1. **Happy path** — three records at confidences 0.9 / 0.85 / 0.3 compose to two
   sentences, the `.high` one first, with "and" joining the first two.
2. **Error/empty path** — zero `.detectedObject` records returns
   `phrasing.nothingRecognized(locale:)` exactly; a records array of only
   `.depthReading`/`.recognizedText`/`.detectedSound` does the same.
3. **Edge case** — every record in one bucket yields exactly one sentence;
   `.concise` caps the list at two labels; a `0.0`-confidence record still
   produces a `.low`-hedged sentence and never an unhedged one.
4. **Doctrine assertion** — for a random mix of confidences, every sentence in
   the output starts with one of `Phrasing.hedgeFragments(locale:)`. This is the
   test that fails if someone later "simplifies" the hedge away.

**Acceptance:**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter SceneComposerTests
cd app && xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS' 2>&1 | tail -20
```

PASS in both (the second compiles the String Catalog, so the es/vi conjunction
behaviour is actually exercised).

- [ ] **Step 3: Commit** — `feat(reasoning): group label-list descriptions by certainty instead of repeating a sentence per object`

---

### Task 4: `FoundationModelsSceneComposer` — detail-aware guide, plus a structural word ceiling

**Files:**

- Modify: `app/SenseBridge/Features/SceneDescription/FoundationModelsSceneComposer.swift`

**Interfaces:** `init(phrasing:locale:detail:)` gains `detail: SpokenDetail = .standard`.
`compose(from:)` unchanged.

- [ ] **Step 1: Give the model room to join more labels, not to embellish**

`@Guide(description:)` is a macro argument. **Try a `static let` string first;
if the macro rejects a non-literal expression, fall back to two `@Generable`
structs** — `SceneSubject` (the existing ≤12-word guide, used for `.concise`
and `.standard`) and `DetailedSceneSubject` (a ≤24-word guide, `.detailed`) —
and pick between them in `modelPhrase(for:)`. Do not resolve this by dropping
the guide and steering length from the prompt alone: the whole point of
`@Generable` here is that the constraint is structural, at the decoding layer,
rather than a request the model may forget (`docs/SAFETY-FRAMING.md`).

Whichever path compiles, **the guide's prohibitions are identical at every
level** and must be copied verbatim from the existing one: article first,
joined with "and", *name only what the list contains*, no verbs, no sentence, no
trailing punctuation, and **no mention of distance, direction, danger, or
safety**. Add one clause: `No adjectives or details that are not in the list.`
The extra word budget exists to join five labels, not to describe any one of
them.

- [ ] **Step 2: Add the input-scaled ceiling as a real check**

`FoundationModelsSceneComposer` runs no validator today, because `@Generable` is
its structural guarantee. That guarantee covers *shape*, not length once the
guide's word count is a variable. Add a deterministic post-check in
`modelPhrase(for:)`, right beside the existing empty-string guard, using the
same fail-closed convention — return `nil`, fall back, never surface the text:

```swift
            let phrase = response.content.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            // An empty or degenerate reply must not become "it looks like
            // there's ." — fall back to reading the labels out instead.
            guard !phrase.isEmpty else { return nil }
            // The guide asks for a word budget; this enforces it. Fail closed,
            // exactly like every other failure mode in this method: an
            // over-long phrase means the model started describing rather than
            // naming, and the label-list composer says the same thing less
            // fluently but within its evidence.
            guard phrase.split(separator: " ").count
                <= detail.maximumPhraseWords(labelCount: labels.count) else { return nil }
            return phrase
```

- [ ] **Step 3: Pass `detail` into the instructions**

`instructions(locale:)` becomes `instructions(locale:detail:)`. Keep every
existing sentence and the locale pin from Task 13 of the 2026-08-11 plan; append
only a length steer (`Use at most N words.`). Nothing about hedging, distance,
direction, or safety changes.

**Acceptance:**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

`** BUILD SUCCEEDED **`. **State plainly in the commit body and the session log
that this is a compile-only result.** The model path needs a real
Apple-Intelligence-capable device to run at all, so CI proves the guide compiles
and the ceiling is wired, not that the model obeys either.

- [ ] **Step 4: Commit** — `feat(scene-description): scale the on-device phrase budget with detail level and enforce it structurally`

---

### Task 5: Plumb the word ceiling through the network path

**Files:**

- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningOutputValidator.swift:28,61-89`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/AnthropicSceneComposer.swift`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/OpenAICompatibleSceneComposer.swift`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningComposerResolver.swift:23-101,155-187`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningOutputValidatorTests.swift`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningComposerResolverTests.swift`

**Why this task is not optional.** `ReasoningOutputValidator.maximumWords` is a
hard 12 (`ReasoningOutputValidator.swift:28`). Leave it, and a user on a cloud
or self-hosted backend who selects "Detailed" gets a longer valid phrase
rejected → thrown → silent fallback to on-device. The picker would appear inert
*and* quietly downgrade their chosen backend. That is AGENTS.md doctrine 4's
first corollary — "never offer a choice that delivers nothing" — and it is the
single most likely way this feature ships broken. Self-review finding R5.

- [ ] **Step 1: Make the ceiling injectable, keep every other rule frozen**

`ReasoningOutputValidator` gains `public init(maximumWords: Int = 12)` and
stores it. **No other rule changes.** Numerals, sentence punctuation, newlines,
`disallowedTerms` (distance/direction/danger/safety), hedge-fragment detection,
and the `NLLanguageRecognizer` check all keep their current behaviour and
thresholds. Update the `tooLong` doc to say the ceiling is now supplied by the
caller from `SpokenDetail`, and that a higher ceiling is a length allowance and
never a content allowance.

- [ ] **Step 2: Thread `detail` from `Settings` to the validator**

- `AnthropicSceneComposer.init` / `OpenAICompatibleSceneComposer.init` gain
  `detail: SpokenDetail = .standard`; each builds its validator with
  `ReasoningOutputValidator(maximumWords: detail.maximumPhraseWords(labelCount: labels.count))`
  **inside `compose(from:)`**, after `labels` is known — the ceiling is
  input-scaled, so it cannot be fixed at construction.
- Both composers append the same one-sentence length steer to their
  `instructions(locale:)` that Task 4 adds. Every existing prohibition stays
  word for word.
- `NetworkComposerFactory.composer(...)` gains a `detail: SpokenDetail`
  parameter. Update `LiveNetworkComposerFactory` and the test stub in
  `ReasoningComposerResolverTests.swift`.
- `ReasoningComposerResolver.compose(from:settings:locale:requestTimeout:)`
  passes `settings.spokenDetail` into the factory. No other resolver behaviour
  changes — the circuit breaker, the probe cadence, the announcements, and the
  not-configured-is-not-a-failure rule are all untouched.

- [ ] **Step 3: Test**

- `ReasoningOutputValidatorTests` — a 20-word phrase is rejected at the default
  ceiling and accepted at `SpokenDetail.detailed`'s; **and, at the raised
  ceiling, a phrase containing "meters", "left", "safe", a numeral, a full stop,
  or a hedge fragment is still rejected.** That second assertion is the one that
  proves a length allowance did not become a content allowance.
- `ReasoningComposerResolverTests` — the stub factory records the `detail` it
  was handed and it matches `settings.spokenDetail`.
- A regression test asserting `detectedObjectLabelsForNetwork()` output is
  byte-identical before and after this task (self-review finding R4: nothing new
  goes on the wire).

**Acceptance:**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter ReasoningOutputValidatorTests
cd app/Packages/SenseBridgeCore && swift test --filter ReasoningComposerResolverTests
cd app/Packages/SenseBridgeCore && swift test --filter PerceptionRecordNetworkPayloadTests
```

All PASS.

- [ ] **Step 4: Commit** — `feat(reasoning): scale the network output validator's word ceiling with detail level`

---

### Task 6: Plumb `spokenDetail` into the three classifier sites and the two composer sites

**Files:**

- Modify: `app/SenseBridge/Features/ObstacleAwareness/AmbientAwarenessSession.swift:71,115`
- Modify: `app/SenseBridge/Features/SceneDescription/SceneDescriptionView.swift:11,27-40,93-123`
- Modify: `app/SenseBridge/Features/Labeling/LabelingView.swift:11,66`

**Interfaces:** No new types. `ObjectClassificationService` is constructed with
`maximumLabels: settings.spokenDetail.maximumLabels` instead of its default;
`FoundationModelsSceneComposer` and `LabelListSceneComposer` are constructed
with `detail: settings.spokenDetail`.

- [ ] **Step 1: `AmbientAwarenessSession`**

`private let classifier: ObjectClassificationService = .init()` (line 71)
becomes a `private var` assigned in `start(environment:)` beside the existing
`engine`/`throttle` assignment (around line 125), so a detail change made in
Settings takes effect on the next session start — the same lifetime the alert
distance and narration interval already have. Pass `detail:` into the
`FoundationModelsSceneComposer(...)` built at line 115.

**Do not change `minimumPrecision`.** Construct as
`ObjectClassificationService(maximumLabels: environment.settings.spokenDetail.maximumLabels)`
and let the precision floor keep its default.

- [ ] **Step 2: `SceneDescriptionView` and `LabelingView`**

Both hold `private let ... = .init()` on a `View` struct, so they cannot read
`@Environment` at init. Construct the classifier inside the action method
(`captureAndDescribe()` / the labeling capture path) from
`environment.settings.spokenDetail`. `SceneDescriptionView`'s `resolver` is
built in `init()` and reads settings per call already, so only
`FoundationModelsSceneComposer(detail:)` needs the value — pass
`.standard` at construction and let the resolver's settings-driven network path
carry the user's choice, **or** move resolver construction into
`captureAndDescribe()`. Prefer the second: it is a one-shot capture, the
comment at `SceneDescriptionView.swift:22-26` already says a fresh resolver per
use is fine, and it removes the stale-settings gap outright.

- [ ] **Step 3: Note the accepted tradeoff in a comment**

At `.detailed`, five labels reach `FoundationModelsSceneComposer`, whose hedge
comes from the **weakest** confidence in the frame
(`FoundationModelsSceneComposer.swift:104-107`). A fifth, marginal detection
will therefore often drag the whole sentence to `.low` ("there might be …").
That is the cautious direction and must not be "fixed" by averaging — the
comment there already explains why averaging launders a doubtful label. Record
it as an intentional consequence, and as a thing the device listen in Task 10
must actually judge. Users who find it too hedged have `.standard`.

**Acceptance:**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
npm run lint:swift
```

`** BUILD SUCCEEDED **`, 0 violations.

- [ ] **Step 4: Commit** — `feat(app): apply the spoken-detail preference to classification and composition`

---

### Task 7: Settings UI + String Catalog (`en`/`es`/`vi`)

**Files:**

- Modify: `app/SenseBridge/App/SettingsSections.swift` (add `DetailLevelSettingsSection`)
- Modify: `app/SenseBridge/App/SettingsView.swift` (insert the section next to `AwarenessSettingsSection`, around line 98)
- Modify: `app/SenseBridge/Resources/Localizable.xcstrings`

**Interfaces:** `struct DetailLevelSettingsSection: View { @Binding var spokenDetail: SpokenDetail }`,
bound via the existing `binding(\.spokenDetail)` helper (`SettingsView.swift:228`).

- [ ] **Step 1: Build the section**

A `Picker` with three entries. Follow `AwarenessSettingsSection`'s established
shape exactly: `Section { } header: { } footer: { }`, `Color("SecondaryText")`
on header and footer, an `.accessibilityHint` on the control. **Zero unlabeled
elements** is a hard gate (AGENTS.md).

Copy, sentence case for prose per the capitalization skill, Title Case for the
labels:

- Header: `Descriptions`
- Picker label: `Description detail`
- Options: `Brief` / `Standard` / `Detailed`
- Hint: `Sets how many things each description names and how much wording it uses.`
- Footer — this is doctrine 4's disclosure, and it is required, not decoration:

  > More detail means SenseBridge names more of what it recognized, not that it
  > is more sure about any of it. Every description is still a cautious guess,
  > and SenseBridge still never says the way ahead is clear.

- [ ] **Step 2: Add every new string to the app catalog in `en`, `es`, `vi`**

Five keys. The footer is physical-world doctrine language, so flag it in the
commit body for the same native-speaker review already tracked for three Core
catalog strings in `TODO.md:1295-1299` — and add it to that existing item rather
than opening a second one.

**Acceptance:**

```bash
npm run check:catalog-coverage
npm run lint:md
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -20
```

`check-catalog-coverage: every key with translations carries es and vi.`

- [ ] **Step 3: Commit** — `feat(settings): add the description-detail preference with es/vi copy`

---

### Task 8: Tests — unit coverage plus the e2e floor of three

**Files:**

- Create: `app/SenseBridgeUITests/DescriptionDetailUITests.swift`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PhrasingTests.swift`

**Interfaces:** None — test-only.

- [ ] **Step 1: Three e2e tests, per `AGENTS.md`'s floor**

Model them on `LanguageSelectionUITests.swift`, which already drives a Settings
picker end to end:

1. **Happy path** — open Settings, select `Detailed`, background and relaunch,
   assert the picker still reads `Detailed` (the setting persists through the
   `Settings` decode path Task 2 touched).
2. **Error path** — with `Detailed` selected on a device or simulator with no
   camera authorization, the Describe screen still speaks its existing
   authorization message and does not crash or emit an empty description.
3. **Edge case** — every one of the three options is reachable and selectable
   via VoiceOver's accessibility tree, and the footer text is exposed as its own
   element (a disclosure a screen-reader user cannot reach is not a disclosure).

- [ ] **Step 2: One doctrine test in `PhrasingTests`**

Assert that for every `SpokenDetail` and every `Certainty`, the string
`Phrasing.describe(subject:certainty:locale:)` returns still contains a hedge
fragment from `Phrasing.hedgeFragments(locale:)` in `en`, `es`, and `vi`. This
is the test that fails if a future change makes detail level reach into hedging.

**Acceptance:**

```bash
cd app/Packages/SenseBridgeCore && swift test
cd app && xcodebuild test -scheme SenseBridge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -30
```

All PASS. Record the actual suite/test counts in the commit body — do not carry
over the counts from a previous session.

- [ ] **Step 3: Commit** — `test: cover the description-detail preference end to end`

---

### Task 9: Docs sync, `TODO.md` closure, `GAPS.md`

**Files:**

- Modify: `docs/ARCHITECTURE.md` ("On-device AI pipeline", around lines 133-161)
- Modify: `docs/PRODUCT.md`
- Modify: `docs/TESTING.md` (the new e2e trio)
- Modify: `TODO.md`
- Modify: `GAPS.md` (only if an entry is genuinely resolved)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Architecture**

Add a short subsection under "On-device AI pipeline" stating: detail level
scales object count and phrase length only; the precision floor, the hedge
templates, and the certainty buckets are level-independent; and
`LabelListSceneComposer` now groups by certainty bucket so the
no-Apple-Intelligence path stops repeating a stock sentence per object. Keep the
existing "The model never writes the sentence" text exactly as it is — it is
still true and this plan depends on it staying true.

**Do not touch `docs/AI-MODELS.md`'s license ledger.** No model, no weights, no
training data, no dependency changed. Adding a row would misrepresent the change.

**Do not touch `docs/PRIVACY.md` or `legal/**`.** Nothing about what leaves the
device changed.

- [ ] **Step 2: Close the `TODO.md` item this plan was written against**

`TODO.md:299-314`, `**[P3]** Configurable spoken-output verbosity`, is exactly
this work. Tick it per `TODO.md`'s Item Completion convention — bold
`**Done 2026-08-12**` naming `SpokenDetail`, the Settings section, and how it
was verified (which commands passed, and explicitly that the device listen is
separate) — then, in the same change:

```bash
npm run todo:sweep && npm run todo:archive
```

- [ ] **Step 3: Add the new deferred items to `TODO.md`**

One entry per "Deferred to Kevin" item below, `[Needs owner]` where it is
Kevin's decision, with file and symbol names so a future agent with zero session
context can act. Also add the caught-but-not-fixed item from self-review R9:
hedge templates are lowercase, so captions render sentence-initial lowercase;
fixing it means re-pinning doctrine strings in three languages and belongs with
the native-speaker review already tracked at `TODO.md:1295-1299`.

**Acceptance:**

```bash
npm run lint:md && npm run check:links && npm run todo:sweep:check
```

All green.

- [ ] **Step 4: Commit** — `docs: sync architecture, testing, and TODO for the description-detail preference`

---

### Task 10: Full verification, device install, reviewer sign-off

- [ ] **Step 1: Machine gates**

```bash
npm run verify        # lint + format + check
cd app/Packages/SenseBridgeCore && swift test
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -20
cd app && xcodebuild test -scheme SenseBridge -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -30
cd app && xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS' 2>&1 | tail -20
```

- [ ] **Step 2: Device install — required, not optional**

```bash
npm run app:install
```

Per `CLAUDE.md` "Hand it back testable": a simulator build does not count, and
the phone must be unlocked or the developer disk image will not mount. A Stop
hook blocks the turn until this runs.

- [ ] **Step 3: Escalated-but-not-fully-escalable check, stated honestly**

The e2e trio in Task 8 automates persistence, the error path, and VoiceOver
reachability. What it **cannot** automate is whether `.detailed` sounds better
or merely chattier, and whether the weakest-confidence rule leaves five-object
descriptions permanently stuck on "there might be". That is a listen, on a
device, by a person. Narrow it to exactly that and hand Kevin the script:

> Open Awareness, start hands-free awareness, walk one loop of a cluttered
> room at `Standard`, then repeat at `Detailed`. Report: (a) does `Detailed`
> name useful extra things or noise, (b) does it get stuck on "there might be",
> (c) is the channel too chatty at your current "Time between descriptions".

- [ ] **Step 4: Safety-framing-reviewer sign-off — blocking**

Dispatch `safety-framing-reviewer` over the full diff. Every task here touches
spoken output, which is the highest-severity surface in the repo. Persist
findings with `audits/scripts/new-audit.sh safety-framing "<title>"`. **Do not
merge on a green pipeline alone** — `AGENTS.md` is explicit that CI cannot prove
on-device latency, thermals, or blind-tester validation, and a green pipeline
must never imply validation it did not do.

- [ ] **Step 5: Session log** — `sessions/2026-08-12/<HHMM>-PST.md`, with
      machine-verified vs. device/human-pending separated.

---

## Self-review pass — what the adversarial read caught and changed

Reviewed against `docs/SAFETY-FRAMING.md`, `AGENTS.md`'s four doctrines, and the
`safety-framing-reviewer` persona's checklist, looking specifically for tasks
that would make output sound more certain, more precise, or more AI-confident
than LiDAR and Vision actually support, and for anything smuggling in a
dependency, endpoint, or dataset.

- **R1 — Struck an entire task: the frame-position clause.** The first draft
  added "toward the left of the camera's view" to descriptions, computed
  deterministically by `Phrasing` from `DetectedObject.boundingBox` — data the
  app already has and already draws on screen. Removed, for three reasons.
  (a) `ReasoningOutputValidator.disallowedTerms` bans "left", "right", "ahead"
  in `en`/`es`/`vi` precisely because directional words are claims about the
  physical world; reintroducing them through a different door does not make them
  a different class of claim. (b) The mount pitch is uncalibrated — `DepthGeometry`'s
  own doc comment calls the strap "a piece of elastic the user re-tightens every
  morning" — so "left of the camera's view" is not "left of you", yet that is
  how it will be heard by someone walking. (c) It needs new doctrine-pinned
  `es`/`vi` strings, and `TODO.md:1295-1299` already has three such strings
  waiting on native-speaker review. Moved to "Deferred to Kevin", item 2.
- **R2 — Struck a precision-floor reduction.** The draft had `.detailed` lower
  `ObjectClassificationService.minimumPrecision` from 0.7 to 0.6 to surface more
  objects. That file's own comment explains the floor rides Vision's
  precision/recall curve *because* the app speaks its output as a claim; and
  `minimumRegionArea` (0.02) is documented as "the single largest accuracy win
  here". Detail level now changes `maximumLabels` and nothing else. Frozen in
  Global Constraints so it cannot creep back.
- **R3 — Replaced a flat 20-word budget with an input-scaled one.** A fixed
  ceiling handed two labels is 16 words of room to invent "a worn wooden chair"
  from a classifier that only said "chair". `maximumPhraseWords(labelCount:)`
  gives four words per label plus four — enough to join what is there, not
  enough to add what is not. Added a matching fail-closed length check to
  `FoundationModelsSceneComposer`, which previously ran no post-check at all
  because `@Generable`'s guarantee covered shape and the guide's length was
  constant.
- **R4 — Verified nothing new reaches the network.** No task adds a field to
  `[PerceptionRecord].detectedObjectLabelsForNetwork()`. `.recognizedText`,
  `.detectedSound`, `.depthReading`, confidences, and bounding boxes all stay on
  the device. Added an explicit regression test (Task 5, Step 3) rather than
  asserting it in prose.
- **R5 — Caught a control that would have delivered nothing.** `.detailed` plus
  any network backend would have hit the hard 12-word ceiling at
  `ReasoningOutputValidator.swift:28`, thrown, and silently fallen back to
  on-device: the picker appears inert *and* downgrades the user's chosen
  backend. That is AGENTS.md doctrine 4's first corollary. Task 5 exists solely
  because of this finding.
- **R6 — Dependency, endpoint, and asset audit, task by task.** Foundation
  (`ListFormatStyle`, `MeasurementFormatter`), Apple Vision, and FoundationModels
  only — all already in use. The abbreviation table is a Swift dictionary in a
  git-tracked source file, not a bundled asset, not a model, not a dataset. No
  new URL, no new `Info.plist` key, no ATS change. Clean.
- **R7 — Fixed a certainty-laundering bug in the draft of Task 3.** The first
  version of the grouped label-list composer joined all labels into one list and
  took the certainty of the first record, which would speak a 0.3-confidence
  detection under `.high`'s "likely". Rewritten to strict per-bucket grouping,
  with a test that every emitted sentence starts with a known hedge fragment.
- **R8 — Named a usability regression rather than assuming it away.**
  `NarrationThrottle` dedupes on exact string equality, so richer descriptions
  change more often and get suppressed less: `.detailed` will be chattier than
  the object count alone suggests. No code change — the user's existing "Time
  between descriptions" slider is the mitigation, and doctrine 4 says let them
  choose — but it is now an explicit question in the device listen (Task 10,
  Step 3) instead of a surprise.
- **R9 — Found and deliberately did not fix:** hedge templates are lowercase
  ("it looks like there's %@."), so the caption channel renders sentence-initial
  lowercase. Correct for speech, wrong on screen. Fixing it means re-rendering
  doctrine-pinned strings in three languages, which belongs with the native
  review already queued at `TODO.md:1295-1299` — not in this diff. Logged in
  Task 9, Step 3.

---

## Deferred to Kevin

Everything below is out of scope for tonight and needs a decision only the owner
can make. Each carries concrete options and a recommendation.

### 1. Real model work — "give it more trained detail or datasets"

Not executable overnight, and it is a cost/privacy/licensing decision, not an
implementation ticket.

- **Option A — Nothing.** Stay on Apple Vision + Foundation Models. Zero license
  risk, zero bundle growth, zero maintenance, and Apple owns the accuracy claim.
  Tonight's plan already lifts perceived quality without touching a model.
- **Option B — Train a Core ML vision classifier with Create ML** on a
  permissively-licensed dataset, following the precedent this repo already set
  with `models/sound-classifier/`. Cost: per-item license verification, which
  `audits/model-license/20260805-000315-esc-50-...` shows is the expensive part
  (the ESC-50 compilation turned out CC BY-**NC** and unusable), plus bundle
  size, plus SenseBridge then owning an accuracy claim Apple currently owns.
- **Option C — Bundle a permissively-licensed open vision-language model** as
  the local tier the 2026-08-11 spec already reserved a disclosure row for.
  Blocked on: a full license audit, roughly gigabyte-scale bundle growth,
  thermal behaviour during continuous awareness, and the fact that `apple-amlr`
  and AGPL — which cover several obvious candidates — are hard blockers per
  `AGENTS.md`.

**Recommendation: A now, B only if field testers name specific object classes
the app keeps missing.** Choosing a dataset before there is evidence of what is
missing buys license and maintenance cost for an unmeasured gain, and this repo
has already paid that bill once.

### 2. Spatial phrasing ("toward the left of the camera's view") — struck in self-review

- **Option A — Don't build it.** The uncalibrated mount means the frame's left
  is not reliably the user's left, and the app has no way to say so in four
  words while someone is walking.
- **Option B — Build it narrowly:** only when the description came from exactly
  one detection (so the position is attributable), only at `.detailed`, worded
  strictly as a statement about the camera's view, with `es`/`vi` written by a
  native speaker before merge.
- **Option C — Visual and caption channels only.** The outline already shows
  position to anyone who can see it; add it to the caption text and never to
  speech.

**Recommendation: A until a blind tester asks for it.** This is the exact shape
of feature `docs/SAFETY-FRAMING.md` names as the most dangerous thing the
project could build, and it should be pulled by a user, not pushed by a plan.

### 3. What the shipped default detail level should be

- **Option A — Ship `.standard` (as planned), flip after a device listen.**
  Users still get grouped sentences, expanded abbreviations, and correct
  articles by default tonight.
- **Option B — Ship `.detailed` as the default.** Delivers "more descriptive"
  immediately, but changes the highest-severity surface in the app on the
  strength of a compile.
- **Option C — Ship `.standard` and ask once during onboarding.** More agency,
  one more decision on a screen a first-time blind user is already navigating.

**Recommendation: A.** It is one setting toggle away from B once you have
actually heard both, and reversing B after a bad listen means another release.

### 4. Extending the abbreviation table with real Vision identifiers

The table in `SpokenPhrase` is seeded from identifiers I could name with
confidence, not enumerated from the framework — say so, do not imply coverage.

- **Option A** — Leave it seeded; extend when a tester reports a mispronunciation.
- **Option B** — Add a `#if DEBUG` dump of the classifier's known identifiers,
  run it once on device, and extend the table from real data.
- **Option C** — Leave it alone permanently and rely on the speech synthesizer.

**Recommendation: B, next session.** It is ten minutes on a device and converts
a guess into a list.

### 5. Sounds and recognized text in scene descriptions

Genuinely "more comprehensive", genuinely not tonight. `.detectedSound` is
dropped by every composer, and `OCRService` runs only in `ReadingView` — and it
discards Vision's per-observation confidence, so there is nothing to derive a
hedge from without changing its return type.

- **Option A** — One-shot Describe screen only. No continuous cost, user is
  actively waiting.
- **Option B** — Both Describe and hands-free awareness. Adds a perception pass
  to the only continuous loop in the app: battery and thermal impact that no CI
  job can measure.
- **Option C** — Neither.

**Recommendation: A, next session.** It needs `OCRService` to return confidence
first, which is its own small change with its own tests.
