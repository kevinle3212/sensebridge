#!/usr/bin/swift
import Foundation

// Maps ESC-50's category names to this project's target class names.
// Only "dog" and "crying_baby" are sourced from ESC-50 here, and only via
// its ESC-10 subset (CC BY 3.0) — the ESC-50 compilation as a whole is
// CC BY-NC 3.0 and unusable in a shipped product. The other five classes
// (siren, car_horn, glass_shatter, knock, fire_alarm) are sourced from
// individually-verified Freesound clips instead; see
// freesound-training-data/MANIFEST.csv and README.md for that process and
// why an earlier version of this script wrongly pulled them from ESC-50.
let categoryMap: [String: String] = [
    "dog": "dog_bark",
    "crying_baby": "baby_cry"
]

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("Usage: prepare-training-data.swift <esc50-checkout-path> <output-path>")
    exit(1)
}
let esc50Path = URL(fileURLWithPath: arguments[1])
let outputPath = URL(fileURLWithPath: arguments[2])
let audioDir = esc50Path.appendingPathComponent("audio")
let metaCSV = esc50Path.appendingPathComponent("meta/esc50.csv")

let csv = try String(contentsOf: metaCSV, encoding: .utf8)
let rows = csv.split(separator: "\n").dropFirst() // drop header

var copiedCount = 0
for row in rows {
    let columns = row.split(separator: ",")
    guard columns.count > 3 else { continue }
    let filename = String(columns[0])
    let category = String(columns[3])
    guard let targetClass = categoryMap[category] else { continue }

    let classDir = outputPath.appendingPathComponent(targetClass)
    try FileManager.default.createDirectory(at: classDir, withIntermediateDirectories: true)
    let source = audioDir.appendingPathComponent(filename)
    let destination = classDir.appendingPathComponent(filename)
    if FileManager.default.fileExists(atPath: source.path) {
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        copiedCount += 1
    }
}
print("Copied \(copiedCount) clips across \(Set(categoryMap.values).count) classes to \(outputPath.path)")
