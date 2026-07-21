// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SenseBridgeCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "SenseBridgeCore", targets: ["SenseBridgeCore"])
    ],
    targets: [
        .target(
            name: "SenseBridgeCore",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "SenseBridgeCoreTests", dependencies: ["SenseBridgeCore"])
    ]
)
