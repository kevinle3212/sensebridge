---
title: Awareness feature completion + on-device/local/cloud reasoning tiers
---

# Awareness feature completion + on-device/local/cloud reasoning tiers

Design for finishing the Awareness feature (`ObstacleAwarenessView` +
`AmbientAwarenessSession`) to production/investor-demo quality, and building
the reasoning backend the owner asked for: **On-Device** (Apple Foundation
Models), **Local — self-hosted endpoint** (user's own LAN/internet server),
and **Cloud** (BYOK: Anthropic, OpenAI, NVIDIA NIM). A fourth bucket, a
bundled on-device model, is named in the UI as not-yet-available rather than
built — see "Bundled local model" below for why that's a change from the
first draft.

Owner decisions this design is built on:

- TODO.md's 2026-08-04 reasoning-backend interview: opt-in, opt-out-anytime
  cloud tier, BYOK, data-minimized (labels/OCR text only, never pixels/audio),
  Keychain-only key storage, non-pre-checked per-provider ToS acknowledgment,
  cloud always additive to the free on-device default.
- 2026-08-11 (this session): "Local" covers both a bundled on-device model and
  a self-hosted endpoint, so the user picks whichever setup is easiest. Cloud
  ships Anthropic + OpenAI + NVIDIA NIM.
- 2026-08-11, second pass: design reviewed by Opus 5 (`advisor` agent) before
  implementation, per owner request. Verdict was **approved with changes** —
  two blockers (a hedge-enforcement gap and a depth-loop stall) and a long
  list of hardening this revision incorporates. Everywhere this revision
  departs from what was already approved, it's called out explicitly rather
  than silently folded in.

## Scope boundary, stated plainly

Everything below ships as real, working code this session **except** the
bundled local model. First draft scaffolded a `BundledLLMSceneComposer`
conformance and a disabled Settings enum case for it; this revision drops
both (see "Bundled local model"). The follow-up (model choice, Core ML
conversion, license ledger entry, on-device benchmarking) is tracked in
TODO.md as its own item.

## Architecture

### Unify on `SceneComposer`, retire `CloudReasoningAdapter`

`CloudReasoningAdapter` (`CloudOptional/CloudReasoningAdapter.swift`) has zero
conformances today and an identical shape to `SceneComposer`
(`compose(from:) async throws -> String`). Delete it and `CloudOptional/`;
every backend conforms to `SceneComposer`.

Collapsing on-device and network composers into one protocol does lose the
ability to distinguish them by type — needed for the in-flight/cost-control UI
below. That distinction lives as **data, not a type hierarchy**:

```swift
extension ReasoningBackend {
    var usesNetwork: Bool { self == .localEndpoint || self == .cloud }
}
```

The resolver already knows which backend it chose; nothing needs a second
protocol to ask "is this one a network call."

### Where the new composers live

`AnthropicSceneComposer` and `OpenAICompatibleSceneComposer` go in
**`SenseBridgeCore/Reasoning/`**, not the App layer — unlike
`FoundationModelsSceneComposer`, nothing about them requires a framework the
core package can't depend on (`URLSession` is Foundation). Each takes an
injected `URLSession` so the whole request/response/validator matrix runs
under `swift test`, no Xcode or simulator required — the same reason the
`SenseBridgeCore` package seam exists at all (`docs/ARCHITECTURE.md`).
Credential storage follows the existing `SettingsStore`/
`UserDefaultsSettingsStore` split: an `APICredentialStore` protocol in the
package, a Keychain-backed implementation in the App layer.

### `OpenAICompatibleSceneComposer` covers three backends

Base URL + optional key + model name is the whole delta between OpenAI cloud,
NVIDIA NIM, and a self-hosted endpoint (Ollama, LM Studio, vLLM all expose an
OpenAI-compatible `/v1/chat/completions` route) — one implementation serves
all three. Two things this revision adds that the first draft assumed away:

- **The key is optional on this composer**, not just on the self-hosted path —
  a self-hosted NIM container commonly needs no key at all, and hosted NIM
  uses namespaced model IDs rather than OpenAI's. Hosted-NIM and self-hosted
  are **separate consent copies** (one names NVIDIA as the recipient, the
  other names the address the user typed), even though they share an
  implementation.
- **`response_format: json_schema` is a request, not a guarantee** — providers
  and self-hosted servers vary on whether they honor forced structured output.
  This mattered a lot in the first draft, where the schema *was* the safety
  mechanism. It's downgraded to a quality-of-output nicety now that the
  output validator below is the actual enforcement point — a provider that
  ignores the schema degrades to "gets rejected and falls back," not "speaks
  an unhedged claim."

### The output validator — the actual safety enforcement point

**This is the correction to the first draft's central claim.** The first
draft said the network composers stay safe because they're prompted the same
way `FoundationModelsSceneComposer` constrains its model. That's not true: the
on-device composer is safe because `@Generable` constrains the reply
*structurally, at the decoding layer* — Apple's runtime, not a request you
sent. Over HTTP there is no decoding layer you control. `response_format` is
a request to a server you don't run, and for the self-hosted tier the server
is arbitrary. A remote returning a full, confident, unhedged sentence and
`Phrasing.describe` (`String(format:)`, which wraps *anything*) would produce
something like *"it looks like there's There is a car about 2 feet ahead —
dangerous"* — a distance and danger claim the detector never earned, spoken to
a walking blind user. That's the worst-bug archetype this project's audit
guide names, reachable through an ordinary non-malicious path (a self-hosted
model ignoring the schema; an OpenAI-compat layer silently dropping it).

**Required addition: a local, deterministic `ReasoningOutputValidator`**
between the HTTP response and `Phrasing`, in `SenseBridgeCore/Reasoning/`,
used by every network composer before the phrase reaches `Phrasing.describe`.
Reject (→ throw, caught by the resolver, falls back to on-device — same
contract as `FoundationModelsSceneComposer.modelPhrase(for:)` returning `nil`
today) when the reply:

- contains sentence-terminating punctuation or a newline,
- exceeds ~12 words (matching the existing `@Guide` cap),
- matches a denylist of distance/direction/safety/danger tokens and numerals
  — **localized for en/es/vi**, not just English,
- contains a fragment of any existing `Phrasing` hedge template (a hedging
  remote model would otherwise get double-hedged),
- is empty after trimming,
- fails a lightweight on-device language check (`NaturalLanguage`'s
  `NLLanguageRecognizer` — Apple SDK, on-device, free, no license risk) against
  the request locale, above a confidence threshold. Best-effort, not a hard
  gate on ambiguous short phrases.

**Required test, and it is the regression test for the worst bug in this
project:** a `URLProtocol` mock returning an unhedged, distance-and-danger
full sentence must deterministically throw or resolve to a phrase wrapped in
a known hedge template — never the raw sentence.

### The wire contract: what actually gets serialized

`SceneComposer.compose(from:)` takes `[PerceptionRecord]`, whose `.kind`
includes `.recognizedText` (OCR) alongside `.detectedObject`.
`FoundationModelsSceneComposer` filters to `.detectedObject` only
(`FoundationModelsSceneComposer.swift:84-87`) as a side effect of its
implementation, not a stated rule — the first draft inherited the protocol
without restating it. If a future change ever routes Reading through the
resolver, a user's OCR'd bank statement or medical letter would go to
Anthropic under a design that only ever said "labels only" in prose.

**Stated rule, enforced at the boundary, and tested:** every network composer
serializes `.detectedObject` labels only. `.recognizedText`, `.detectedSound`,
and `.depthReading` records are dropped before the request is built.
Confidence values stay on-device — the hedge is computed from them locally;
the provider never receives them and has no use for them.

### Resolution, concurrency, and fallback

`ReasoningComposerResolver` (App layer — needs `AppEnvironment` for Keychain
and `Settings`) picks the active composer from `Settings`.

**Composition must not block the depth cadence — required change.**
`AmbientAwarenessSession.run` → `tick` → `describeIfDue` → the composer, all
awaited in sequence (`AmbientAwarenessSession.swift:185-194,293`). On-device
that costs a few hundred ms; over a network — cellular, a slow self-hosted
box, a stalled connection — the 750 ms depth loop stalls for the whole
round-trip, breaking the stated invariant that depth sampling never waits on
a narration cadence chosen for comfort (`docs/ARCHITECTURE.md`, "Two
cadences, one loop"). That's a doctrine 1 defect, invisible in the simulator.

Fix: composition runs as a **tracked child `Task`**, single-flight (a tick
that finds one already in flight is skipped, not queued — matching the
existing `environment.speech.isSpeaking` skip-not-queue pattern at
`AmbientAwarenessSession.swift:264-266`), cancelled alongside `loopTask` in
`stop()`. Add a **staleness guard**: if the response arrives after more than
2× `narrationIntervalSeconds` from when its source frame was captured,
discard it — describing a room the user already walked out of is a false
statement about the present, the same principle that already governs stale
detection outlines (`:207-217`).

**Fallback disclosure — three distinct cases, not one "silent" rule.** The
first draft's blanket "any failure falls back silently" undersells doctrine
4's "never let a limitation go unstated." A user who configured and is
paying for a cloud tier and is silently getting free-tier quality has had a
limitation go unstated.

1. **Never configured / consent declined** — on-device is simply the active
   backend; the Settings row already names it. Nothing to announce.
2. **Configured but failing** (timeout, expired key, rate limit, endpoint
   down) — the user believes they're getting a tier they're not.
   **Announce once**, through `NarrationThrottle`'s urgent path so it isn't
   swallowed: *"Cloud descriptions aren't responding, so SenseBridge is
   continuing with on-device descriptions."* Do not repeat per-failure — that
   trains the user to ignore the channel, the same reasoning that already
   governs routine narration.
3. **Configured and working** — nothing to say per request.

**Circuit breaker**, doing double duty as disclosure and cost control: 2
consecutive network failures trips it, dropping to on-device for the rest of
the session with the one announcement above. While tripped, probe the network
composer again every 5th tick rather than every tick (bounds cost against a
still-down endpoint) or every tick (would hammer it); a successful probe
resets the breaker and announces recovery once, so the user isn't left
wondering indefinitely whether the good tier ever came back.

**The in-flight cue is state, not speech.** A cue fired on every request
during hands-free awareness would repeat every `narrationIntervalSeconds`
(default 6s) into the one channel the user is listening to — exactly what
`NarrationThrottle` exists to prevent elsewhere. Instead: an observable
`isAwaitingNetworkResponse` property (for `accessibilityValue`/visual state),
plus the active backend named once, spoken, at session start — extending the
existing "Descriptions are composed on-device by Apple Intelligence" footnote
pattern (`ObstacleAwarenessView.swift:129-136`) to name all three backends.

Both call sites move off their hardcoded `FoundationModelsSceneComposer.init()`
onto the resolver: `AmbientAwarenessSession.start(environment:)` and
`SceneDescriptionView.captureAndDescribe()`.

### Data model (`Settings.swift`)

Replace `cloudReasoningEnabled: Bool` with:

```swift
public enum ReasoningBackend: String, Sendable, Codable {
    case onDevice, localEndpoint, cloud
}
public enum CloudProvider: String, Sendable, Codable {
    case anthropic, openai, nvidiaNIM
}
public var reasoningBackend: ReasoningBackend = .onDevice
public var cloudProvider: CloudProvider?
public var localEndpointURL: String?
```

(No `.localBundledModel` case — see "Bundled local model" below. No
`localEndpointModelName` field either; the model name is part of the request
body, not a durable setting worth its own field yet — pass a sane default per
composer and revisit if a real need for per-endpoint model overrides shows
up.)

**Migration — corrects a bug in the first draft.** `Settings.init(from:)`
currently decodes `cloudReasoningEnabled` with plain `try container.decode`
(non-optional, `Settings.swift:97`) — the first draft didn't account for
this. The new decode must:

- read both the old `cloudReasoningEnabled` key and the new
  `reasoningBackend` key with `decodeIfPresent`, never a throwing decode, or a
  future/corrupted value silently resets the *entire* settings blob to
  defaults (speech rate, output profile, `hasCompletedOnboarding`, all of it)
  rather than just the reasoning field;
- decode an unrecognized `reasoningBackend` raw string to `.onDevice`, not
  throw;
- if `reasoningBackend` is absent but old `cloudReasoningEnabled == true`,
  resolve to `.cloud` with `cloudProvider = nil` — falls straight back to
  on-device via the resolver until the user picks a provider and re-consents,
  same intent as the first draft, just correctly implemented.

Existing tests referencing the old key need updating in the same change:
`SettingsTests.swift:11,25,32,41,64`, `CrashReportingTests.swift:28`.

**API keys never enter `Settings`/`UserDefaults`.** New `APICredentialStore`
(protocol in `SenseBridgeCore`, Keychain implementation in the App layer),
keyed by `CloudProvider` (plus one slot for the self-hosted endpoint's
optional bearer token). Required Keychain attributes the first draft omitted:

- `kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — the
  default (`WhenUnlocked`) rides encrypted backups and can restore onto a
  different device; this is a billing credential, and `docs/ARCHITECTURE.md`
  already plans optional CloudKit settings sync, so `ThisDeviceOnly` keeps the
  key out of both paths.
- `kSecAttrSynchronizable: false`, explicit, for the same reason.
- **Update, not blind add.** `SecItemAdd` returns `errSecDuplicateItem` on a
  second save; a rotated key must go through `SecItemUpdate` (or
  delete-then-add), or the old key silently keeps being used — the most
  common Keychain bug, and it fails in the worst direction.
- **Retention policy, stated.** Switching the backend away from `.cloud`
  does **not** delete the stored key (doctrine 4 — don't discard the user's
  data on their behalf) — Settings needs an explicit "Remove key" control, and
  the footer states the key is retained until removed.
- **Write-only UI.** The Settings screen never reads a stored key back into a
  `SecureField` — it shows "A key is saved" plus Replace/Remove. Keeps the key
  out of view-model state entirely, not just out of storage.

`localEndpointURL` is a destination, not a secret, and stays in `Settings`
(plain `UserDefaults`) as originally planned — but see URL validation below
for what has to happen before it's ever used.

### Consent UX

One `ReasoningBackendSettingsView`, reached from Settings. Segmented picker:
On-Device / Local / Cloud.

- **Local** expands to two rows: **Self-hosted endpoint** (URL field +
  optional token field, real and functional) and **Bundled on-device model**
  (a static disclosure row — see below — not a selectable control).
- **Cloud** expands to a provider picker (Anthropic / OpenAI / NVIDIA NIM,
  key field optional for NIM) plus the key entry described next.

Per TODO's already-approved spec: default off, one-time explicit screen
naming exactly what leaves the device before any network backend can be
turned on, persistent off switch, per-provider ToS acknowledgment
(unchecked, real `Toggle` with its own label/hint — never a bare tap target),
link labeled with its destination, re-shown on every provider switch. The
self-hosted copy says data goes to the address the user typed, on whatever
network that reaches, and SenseBridge has no visibility past that point; if
the URL is `http://`, the copy states the labels travel unencrypted on that
network (doctrine 4 corollary 2 — cleartext isn't a footnote).

**Key entry accessibility — the biggest usability gap in the first draft.** A
blind user cannot proofread a `SecureField` character by character through
VoiceOver. Primary path is a **"Paste key from clipboard"** button; the
`SecureField` is the fallback. Either path ends in a **"Test connection"**
round trip — one lightweight real request — that speaks success or the
specific failure before the backend can be enabled, so the user isn't left
guessing whether a pasted key actually worked.

### Safety framing (highest-severity surface — safety-framing-reviewer sign-off required)

Every network composer is still prompt-constrained the same way
`FoundationModelsSceneComposer` constrains its model — bare noun phrase, no
sentence, no hedge word, no distance/direction/danger claim — but the prompt
is now correctly framed as a *quality* measure, not the safety mechanism. The
**validator is the safety mechanism**: it runs after every network response,
regardless of what the provider claims to support, and nothing reaches
`Phrasing.describe` without passing it. `Phrasing` supplies the hedge from the
detector's confidence exactly as today; a network provider can degrade
phrasing quality (via a rejected/fallback response) but cannot make the app
assert certainty it hasn't earned.

**Pre-existing gap, worth fixing in the same pass since the sibling file is
already open:** `FoundationModelsSceneComposer.instructions` never pins the
output language, while `Phrasing` wraps it in a localized template — an
`es`/`vi` user can get `"có vẻ như có a chair and a doorway."` today. Both the
on-device prompt and the new network prompts should state the target
language explicitly; the validator's language check above is the backstop.

### Self-hosted endpoint — network-layer specifics the first draft didn't cost

- **App Transport Security.** There is no `Info.plist` file in this project —
  everything is `INFOPLIST_KEY_*` build settings (`project.pbxproj:506-511`),
  and there is no ATS key anywhere today. ATS defaults therefore block
  cleartext HTTP, and Ollama/LM Studio both default to plain `http://` — the
  single most likely thing a user types will not connect without a change.
  `NSExceptionDomains` is build-time while the endpoint is runtime user input,
  so a per-domain exception doesn't fit. **Position for implementation:**
  attempt an `NSAllowsLocalNetworking` exception first; verify on a real
  device whether it covers a bare RFC1918 literal (e.g. `192.168.1.20`) or
  only qualified/`.local`/link-local addresses — this is not something a doc
  can answer. If it doesn't cover the common case, restrict the self-hosted
  tier to `https://` only and say so in the field's placeholder/hint, rather
  than reaching for `NSAllowsArbitraryLoads` (disables ATS app-wide,
  unacceptable here).
- **Local Network privacy prompt.** iOS 14+ gates local-network connections
  behind `NSLocalNetworkUsageDescription`; without it a direct-LAN connection
  fails with no useful error. Needs the string, localized en/es/vi, and a
  device check of exactly when the prompt fires for a raw `URLSession`
  connection (vs. Bonjour-discovered services).
- **URL validation at the trust boundary.** Scheme allowlist `http`/`https`
  only; reject a URL carrying embedded `user`/`password` components (the
  design routes tokens through Keychain, but never stated what happens if
  someone pastes credentials into the URL field, and `localEndpointURL` lands
  in plain `UserDefaults`); normalize the path so both `http://host:11434` and
  `http://host:11434/v1/chat/completions` work; cap response size (e.g. 1 MB)
  and require a JSON content type, so a misconfigured host returning an HTML
  page is a fast error, not a hang.
- **No TLS bypass, ever.** No custom `URLSessionDelegate` certificate
  handling, no self-signed-cert acceptance. The pressure to add one will be
  constant once people run this against home servers; the honest answer is
  "trust your CA in iOS Settings," matching the global standard that a
  control never gets softer to make a task easier.

### `URLSession` configuration (applies to every network composer)

`waitsForConnectivity = false` (the platform default of `true` would queue a
request until connectivity returns — exactly the "walking, connectivity
drops mid-session" scenario, resolved tens of seconds later into a
description of somewhere the user no longer is), per-context request
timeouts (~4s for hands-free composition, ~8s for one-shot Describe — a
narration cadence can't afford the platform's 60s default),
`allowsConstrainedNetworkAccess = false` (honors Low Data Mode), and **no
automatic retries anywhere in this stack** — retries are the mechanism that
turns a flaky endpoint into a runaway BYOK bill.

### Cost controls (BYOK-specific — required, not optional)

At the default 6s narration interval, one hour of hands-free awareness is
~600 requests against the user's own API budget. Required:

- no automatic retries (above);
- the circuit breaker (above) — stops hammering a failing/misconfigured
  endpoint;
- **clamp `narrationIntervalSeconds` to a higher floor** (e.g.
  `max(current, 10)`) while a network backend is active, with the reason
  stated at the point of choice;
- a **per-session request counter**, visible in Settings — not analytics, a
  local-only count, reset each session, the one honest way a BYOK user can
  reason about spend without leaving the app.

### Bundled local model — dropped from this pass, kept as a disclosure

First draft scaffolded `BundledLLMSceneComposer` (a real `SceneComposer`
conformance whose `compose` always throws) plus a `.localBundledModel` enum
case, presented as a disabled Settings option. **This revision drops both.**
Reasoning: `ReasoningBackend` is `Codable` and persisted — a case that exists
now is a value that can be persisted now and needs migrating forever, and
when a real bundled model ships it will need its own settings (model
identifier, quantization, download state) that don't fit this enum anyway,
so the case gets rewritten regardless. A disabled radio button that presents
as selectable is also a worse investor-demo experience than a plain
disclosure row — this project already has the right pattern for "planned but
unbuilt" at `DiagnosticsSettingsSection.swift:27-36`: a warning row stating
the reason, not a control the presenter has to explain away.

**What ships instead:** a static, non-interactive row in the Local section —
*"Bundled on-device model — not yet available. Needs a benchmarked model;
tracked as a follow-up."* Satisfies doctrine 4 (named, not hidden) without
persisting a value nothing backs. TODO.md already tracks the real follow-up
(model choice, Core ML conversion, license ledger, on-device benchmarking).

### Awareness feature hardening

- **Fix the mock data.** `ObstacleAwarenessView`'s "Check once" button
  currently toggles a hardcoded `1.0`/`3.0`. Add
  `AmbientSensingSource.sampleOnce() async throws -> Double?`: a short-lived
  ARKit session (start, wait for the first depth frame through the same
  `DepthGeometry`/`DepthStatistics` reduction the continuous loop uses, stop),
  with the same camera-exclusivity handling as `start()`. Three details the
  first draft missed:
  - `sampleOnce()` returning `nil` (ARKit measured nothing, or no frame
    arrived before a timeout) must map to a **distinct "couldn't measure"**
    utterance — never `phrasing.nothingRecognized()`, and never
    `.awarenessClear`. `DepthStatistics` already treats `nil` as "could not
    measure, never the way is clear"; this button must not undo that
    invariant.
  - The view holds `@State private var engine: AwarenessEngine` across taps
    (`ObstacleAwarenessView.swift:65`) — its hysteresis band carries state
    from a previous tap in a previous room, so a fresh 2.0m reading can
    return `.unchanged` and report "something ahead" because a tap ten
    minutes ago read 1.0m. Hysteresis belongs to the continuous loop; a
    one-shot check needs a **fresh `AwarenessEngine` per tap** (or an
    explicit `reset()` before evaluating).
  - Needs an explicit timeout and a spoken "measuring…" state — a cold ARKit
    session start is not instantaneous, and the button currently returns
    synchronously.
- **Handheld vs strapped.** No code change — `AwarenessPreviewFeed`/
  `AwarenessPreviewView` already render whatever ARKit hands them regardless
  of mount or orientation. Confirmed by reading, not assumed; still flagged
  for a device pass since ARKit world-tracking quality at different motion
  speeds is a real-hardware question no simulator answers.
- **Backend visibility.** Extend the existing on-device/fallback footnote in
  `ObstacleAwarenessView` to name all active states (on-device / self-hosted /
  cloud provider name), spoken once at session start per the fallback-
  disclosure design above, plus an `accessibilityValue` on the Settings
  backend row naming the active backend, plus deliberate VoiceOver focus
  movement after enabling/disabling a backend.

## Testing

- `AnthropicSceneComposer` / `OpenAICompatibleSceneComposer`: `URLProtocol`-
  mocked success, malformed JSON, HTTP error, timeout, and — the regression
  test for the worst bug in the project — an unhedged distance/danger
  sentence, asserted to throw or resolve to a validator-passed, hedge-wrapped
  phrase, never the raw string.
- `ReasoningOutputValidator`: table-driven tests over the reject rules
  (punctuation/newline, word count, denylist tokens in en/es/vi, hedge-
  fragment double-wrap, empty, wrong-language).
- Wire-contract test: a `PerceptionRecord` list containing `.recognizedText`
  and `.detectedSound` alongside `.detectedObject` produces a request body
  containing only the object labels.
- `ReasoningComposerResolver`: every `ReasoningBackend` resolves to the right
  composer; every composer failure falls back to on-device; the three-case
  disclosure model (silent / announce-once-on-failure / silent-when-working);
  circuit-breaker trip + probe + recovery-announcement.
- Non-blocking composition: a slow-responding mock composer must not delay
  the depth-sampling tick; a response arriving after `stop()` or past the
  staleness window must not reach `deliver`.
- `Settings` codable migration: old blob with `cloudReasoningEnabled: true`
  and no `reasoningBackend` decodes to `.cloud`/`cloudProvider: nil`; an
  unrecognized `reasoningBackend` string decodes to `.onDevice`, not a thrown
  decode error.
- `APICredentialStore`: save/update/delete round-trip per provider against a
  protocol-mocked store for resolver tests; a real-Keychain smoke test only
  if the existing test setup can run one on-device/in a signed target,
  otherwise flagged device-only.
- `AmbientSensingSource.sampleOnce()`: fixture-buffer unit test for the
  reduction math (existing `DepthStatistics`/`DepthGeometry` coverage
  extends); the ARKit session start/stop itself is device-only.
- e2e floor (3 per changed feature, per `docs/TESTING.md`): happy (cloud
  configured and responding), error (network fails mid-session, circuit
  breaker trips, session keeps narrating via fallback, one announcement),
  edge (switching backends mid-run; empty detection list against a network
  composer; self-hosted URL with embedded credentials rejected at the
  boundary).

## Docs/legal sync (same change) — expanded from the first draft

Shipping any network reasoning tier makes several currently-true "nothing
leaves the device" statements false. First draft's list only covered the
architecture/privacy docs; this revision adds every surface that actually
asserts the old claim:

- `docs/ARCHITECTURE.md` — replace the "Optional Cloud Reasoning Adapter"
  paragraph with the real backend design, the resolver/fallback/circuit-
  breaker behavior, and the non-blocking-composition invariant.
- `docs/AI-MODELS.md` — add Anthropic/OpenAI/NVIDIA NIM as a distinct ledger
  category (third-party service, BYOK, opt-in, not a bundled model — no
  license-bundling question applies, but the ToS-acceptance requirement
  belongs in the same table for visibility).
- `docs/PRIVACY.md` — extend the crash-reporting opt-in precedent to the new
  network paths: what leaves the device (labels only, per the wire contract
  above), when (only after explicit per-provider consent), that the
  self-hosted destination is entirely the user's own choice, and the
  Keychain retention/deletion policy.
- `docs/SECURITY-MODEL.md:137` — currently asserts both camera paths are
  on-device; needs the network-reasoning exception stated the same way the
  crash-reporting exception already is elsewhere in this doc.
- `legal/SUBPROCESSORS.md` — currently states nobody receives camera frames,
  photos, recognized text, audio, depth data, or location, with no path in
  the software that would allow it. Add the BYOK providers with an explicit
  note that the user, not SenseBridge, is the data controller for that path.
  **Draft only** — `legal/`, owner approval required.
- `legal/PRIVACY_POLICY.md:34,181` — same claim, same rule: **draft only**.
- `docs/PRODUCT.md:86` — "100% of MVP features run with no network call" no
  longer holds once a network tier ships, even opt-in.
- `docs/_includes/hero.html:30` and
  `website/src/paraglide/messages/phone_annotation_2_body.js` — both assert
  "nothing leaves the device" on the marketing site; edit the source message
  file, not the generated one, in all three locales.
- `project.pbxproj:506` (`NSCameraUsageDescription`, en/es/vi) — the
  App-Store-facing string currently says "Nothing leaves your device."
  load-bearing enough to need explicit sign-off on new wording, not a
  mechanical edit.
- `GAPS.md:42-49` — the mock-depth-data entry moves to `## Resolved` with a
  dated evidence note once `sampleOnce()` ships.
- `TODO.md` — close the 2026-08-04 reasoning-backend item and this session's
  2026-08-11 design item with what shipped; keep the bundled-local-model
  follow-up (already added) and add a device-validation item for: ATS/local-
  network-permission behavior on a real device, VoiceOver pass on the new
  Settings screens, real cloud/NIM/self-hosted round-trip behavior, and
  thermal/battery of hands-free awareness running against a network
  composer.

## Guardrails for the new tooling

Per AGENTS.md, every new tool/script ships with guardrails. The i18n
completeness check below (if built) needs the same treatment: a narrow,
read-only script that fails CI on a missing catalog key, nothing that writes
or auto-translates.

- **Catalog coverage.** Both `Localizable.xcstrings` (61/61 keys) and the app
  strings catalog (3/3 keys) are fully translated to es/vi today, with no CI
  gate enforcing it. New consent/Settings copy shipping English-only would be
  a visible regression in the one place a machine translation must never
  land unreviewed. A small script asserting every catalog key carries es and
  vi entries makes this permanent; wire it into `npm run check`. New copy
  itself needs native-speaker review, joining the existing outstanding P1
  ES/VI review item in TODO.md rather than duplicating it.

## What stays explicitly unverified after this session

Machine-checkable: build green, unit tests including the validator regression
test, VoiceOver label presence via the existing XCUITest accessibility audit
pattern. **Not** machine-checkable, stated rather than implied:

- whether `NSAllowsLocalNetworking` covers a bare RFC1918 literal or only
  qualified/`.local` addresses (needs a device);
- exactly when the local-network permission prompt fires for a direct
  `URLSession` connection (needs a device);
- which of Anthropic/OpenAI/NIM/Ollama/LM Studio actually honor forced
  structured output in practice (needs live endpoints, not documentation);
- real cloud/self-hosted round-trip latency and behavior on a physical
  network;
- VoiceOver *experience* (not just label presence) on the new Settings
  screens, especially the paste-key/test-connection flow;
- thermal/battery of hands-free awareness with a network composer active;
- that the bundled local model path has no model behind it at all — stated
  in the UI, not hidden, but genuinely not built.

`npm run app:install` at the end proves the build runs on Kevin's device; it
proves none of the above.
