import Foundation

/// A `PerceptionService` that turns captured audio into `.detectedSound`
/// records. Exists as its own protocol (rather than call sites just using
/// `PerceptionService`) so "some SoundService" documents intent the same way
/// `SceneComposer` does for scene composition.
public protocol SoundService: PerceptionService {}
