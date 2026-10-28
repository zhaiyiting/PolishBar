// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Polish",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "polish", targets: ["polish"]),
        .executable(name: "PolishApp", targets: ["PolishApp"]),
        .library(name: "PolishCore", targets: ["PolishCore"]),
        .library(name: "PolishMac", targets: ["PolishMac"]),
    ],
    targets: [
        // Logic + wire codec. No AppKit/Carbon; unit-tested by CoreTests.
        .target(name: "PolishCore"),

        // Shared macOS integration "kernel" (AX, hotkey, pasteboard, LLM client,
        // config/keychain, PolishService). Used by both front-ends.
        .target(name: "PolishMac", dependencies: ["PolishCore"]),

        // CLI front-end (dev): daemon, doctor, exec, stop.
        .executableTarget(name: "polish", dependencies: ["PolishCore", "PolishMac"]),

        // Menu-bar app front-end (users): start/stop + settings.
        .executableTarget(name: "PolishApp", dependencies: ["PolishCore", "PolishMac"]),

        // Dependency-free test harness (runs with `swift run CoreTests`).
        .executableTarget(name: "CoreTests", dependencies: ["PolishCore"], path: "Tests/CoreTests"),
    ],
    swiftLanguageModes: [.v5]
)
