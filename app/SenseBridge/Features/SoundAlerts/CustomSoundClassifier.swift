import CoreML
import Foundation
import SenseBridgeCore
import SoundAnalysis

/// Classifies captured audio using the bundled Create ML model, trained on
/// individually-license-verified clips — see
/// `models/sound-classifier/README.md` for full provenance and training
/// steps. Shares `SoundClassificationRunner` with `BuiltInSoundClassifier`;
/// the only difference is which `SNClassifySoundRequest` gets constructed.
///
/// Lives in the App layer rather than in `SenseBridgeCore`, the same reason
/// `FoundationModelsSceneComposer` does: `SenseBridgeSoundClassifier` is the
/// Xcode-generated Swift wrapper for `app/SenseBridge/Resources/
/// SenseBridgeSoundClassifier.mlmodel`, and that generated type only exists
/// in the App target's compiled module — the device-agnostic package
/// deliberately doesn't depend on it.
///
/// ## History: this model was retrained once already, for two independent reasons
///
/// The first trained version used ESC-50's dataset-wide "CC BY 4.0" claim
/// without checking ESC-50's own license file directly — which turned out to
/// be wrong (the dataset is CC BY-**NC** 3.0 outside its small ESC-10
/// subset). The same version separately trained its `fire_alarm` class on
/// ESC-50's `church_bells` category as a placeholder proxy, which a
/// safety-framing audit caught as a live defect: a church bell or doorbell
/// chime could be announced as a fire alarm. Both problems are fixed in the
/// current model — every clip's license was verified directly on its own
/// Freesound page (`models/sound-classifier/freesound-training-data/MANIFEST.csv`
/// records author/license/source per clip) and `fire_alarm` is now trained
/// on real fire/smoke alarm recordings, not a proxy category. See
/// `audits/model-license/20260805-000315-esc-50-sound-classifier-training-data-license-verification.md`
/// and `audits/safety-framing/20260805-000401-alpha-scaffolding-sound-alerts-onboarding-wired-vision-surfaces.md`
/// for the original findings.
///
/// The classes below are the seven target-class subdirectories under
/// `models/sound-classifier/combined-training-data/`, not
/// `BuiltInSoundClassifier.targetClassNames` — a Create ML sound classifier
/// can only ever predict a class it saw during training; listing anything
/// else here is dead weight, not a harmless superset.
///
/// The training data has an **eighth** class, `background` — deliberately
/// absent from this set. It exists so the model has somewhere to put
/// non-alert audio (room hiss, HVAC, tones) instead of forcing it into the
/// nearest alert class at full confidence; `SoundClassificationRunner`
/// filters every prediction against this set, so a `background` verdict is
/// silently dropped rather than becoming a spoken claim. See
/// `audits/safety-framing/20260806-064241-…-reach-spoken-output.md` (dated
/// prefix is unique under that directory) and `CustomSoundClassifierOODTests`.
struct CustomSoundClassifier: SoundService, Sendable {
    static let targetClassNames: Set<String> = [
        "fire_alarm", "knock", "dog_bark", "baby_cry", "car_horn", "siren", "glass_shatter"
    ]

    /// Language the reported labels are phrased in. Wording only — the
    /// bundled model, its class set, and the confidence floor are identical in
    /// every language.
    let locale: Locale

    /// Creates a classifier over the bundled Create ML model.
    init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Classifies a WAV buffer against the bundled model, dropping anything
    /// outside `targetClassNames` — including the `background` class — before
    /// it can become a spoken claim.
    /// - Parameter input: WAV-encoded audio; an empty buffer yields no records.
    /// - Returns: One `.detectedSound` record per surviving match, phrased in `locale`.
    /// - Throws: Whatever loading the model or running the analysis throws.
    func process(_ input: Data) async throws -> [PerceptionRecord] {
        let model = try SenseBridgeSoundClassifier(configuration: MLModelConfiguration()).model
        let request = try SNClassifySoundRequest(mlModel: model)
        return try await SoundClassificationRunner.classify(
            input, using: request, topClassNames: Self.targetClassNames, locale: locale
        )
    }
}
