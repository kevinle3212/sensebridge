#!/usr/bin/swift
import CreateML
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("Usage: train.swift <training-data-path> <output-mlmodel-path>")
    exit(1)
}
let trainingDataURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

let dataSource = MLSoundClassifier.DataSource.labeledDirectories(at: trainingDataURL)
let classifier = try MLSoundClassifier(trainingData: dataSource)

let metadata = MLModelMetadata(
    author: "SenseBridge",
    shortDescription: "On-device sound classifier for high-value alerts, trained on individually license-verified clips.",
    license: "See CREDITS.md and models/sound-classifier/freesound-training-data/MANIFEST.csv for full per-clip attribution."
)
try classifier.write(to: outputURL, metadata: metadata)
print("Trained model written to \(outputURL.path)")
print("Training accuracy: \(classifier.trainingMetrics.classificationError)")
print("Validation accuracy: \(classifier.validationMetrics.classificationError)")
